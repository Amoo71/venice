import Foundation
import Combine
import WebKit

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var addressInput: String = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var pageTitle: String = "Liquid Browser"
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canGoForward: Bool = false

    @Published var isFeatureMenuOpen: Bool = false
    @Published var isShowingDevTools: Bool = false
    @Published var isShowingProxyEditor: Bool = false
    @Published var isShowingSettings: Bool = false

    @Published var settings: BrowserSettings = Persistence.loadSettings()
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?

    @Published var proxies: [ProxyProfile] = Persistence.loadProxies()
    @Published var activeProxyID: UUID? = Persistence.loadActiveProxyID()

    @Published var networkEvents: [NetworkEvent] = []
    @Published var consoleEvents: [ConsoleEvent] = []
    @Published var blockedEvents: [NetworkEvent] = []
    @Published var extractedLinks: [String] = []
    @Published var pageHTML: String = ""

    @Published var webViewIdentity: UUID = UUID()

    var activeProxy: ProxyProfile? {
        guard settings.useProxy else { return nil }
        guard let activeProxyID else { return proxies.first }
        return proxies.first(where: { $0.id == activeProxyID }) ?? proxies.first
    }

    private weak var webView: WKWebView?
    private let redirectBlocker = RedirectBlocker()
    private var didBootstrap = false

    private var pendingLoadURL: URL?
    private var pendingReload = false

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        if settings.restoreTabsOnLaunch {
            let restoredTabs = Persistence.loadTabs()
            if !restoredTabs.isEmpty {
                tabs = restoredTabs
                selectedTabID = Persistence.loadSelectedTabID() ?? restoredTabs.first?.id
            }
        }

        if tabs.isEmpty {
            let firstURL = normalizeURL(settings.newTabStartPage) ?? URL(string: "https://duckduckgo.com")!
            tabs = [BrowserTab(urlString: firstURL.absoluteString)]
            selectedTabID = tabs.first?.id
        }

        if let current = selectedTab {
            addressInput = current.urlString
            currentURL = URL(string: current.urlString)
            pendingLoadURL = currentURL
        }

        persistTabsIfNeeded()
    }

    func attach(webView: WKWebView) {
        self.webView = webView
        syncNavigationState(from: webView)
    }

    func navigateFromInput() {
        let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let explicit = normalizeURL(trimmed) {
            queueLoad(url: explicit)
            return
        }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        queueLoad(url: URL(string: "https://duckduckgo.com/?q=\(encoded)")!)
    }

    func queueLoad(url: URL) {
        pendingLoadURL = url
        currentURL = url
        addressInput = url.absoluteString
        updateSelectedTab(url: url, title: nil)
    }

    func consumePendingLoadURL() -> URL? {
        defer { pendingLoadURL = nil }
        return pendingLoadURL
    }

    func requestReload() {
        pendingReload = true
    }

    func consumeReloadFlag() -> Bool {
        defer { pendingReload = false }
        return pendingReload
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func syncNavigationState(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        pageTitle = webView.title ?? "Liquid Browser"

        if let url = webView.url {
            currentURL = url
            addressInput = url.absoluteString
            updateSelectedTab(url: url, title: webView.title)
        }
    }

    func recordNavigationStart() {
        isLoading = true
    }

    func recordNavigationFinish(webView: WKWebView) {
        syncNavigationState(from: webView)
        isLoading = false
    }

    func recordNavigationFailure(webView: WKWebView, error: Error) {
        syncNavigationState(from: webView)
        isLoading = false
        consoleEvents.insert(
            ConsoleEvent(
                timestamp: Date(),
                level: "error",
                message: "Navigation failed: \(error.localizedDescription)"
            ),
            at: 0
        )

        guard settings.useProxy, settings.rotateProxyOnFailure else { return }
        rotateProxyAndRebuild()
    }

    func shouldBlockRedirect(
        currentURL: URL?,
        targetURL: URL,
        navigationType: WKNavigationType,
        isMainFrame: Bool
    ) -> Bool {
        guard settings.blockRedirects else { return false }

        let shouldBlock = redirectBlocker.shouldBlock(
            currentURL: currentURL,
            targetURL: targetURL,
            navigationType: navigationType,
            isMainFrame: isMainFrame
        )

        if shouldBlock {
            blockedEvents.insert(
                NetworkEvent(
                    timestamp: Date(),
                    method: "BLOCK",
                    url: targetURL.absoluteString,
                    status: "Redirect blocked",
                    durationMs: nil,
                    source: "redirect-filter"
                ),
                at: 0
            )
        }

        return shouldBlock
    }

    func recordBlockedPopup(_ url: URL?) {
        blockedEvents.insert(
            NetworkEvent(
                timestamp: Date(),
                method: "BLOCK",
                url: url?.absoluteString ?? "unknown",
                status: "Popup blocked",
                durationMs: nil,
                source: "popup-filter"
            ),
            at: 0
        )
    }

    func handleDevToolsBridgeMessage(_ payload: [String: Any]) {
        guard let kind = payload["kind"] as? String else { return }

        if kind == "network" {
            let status = payload["status"] as? String ?? "pending"
            let duration = payload["duration"] as? Int
            let method = payload["method"] as? String ?? "GET"
            let url = payload["url"] as? String ?? ""
            let source = payload["source"] as? String ?? "js"

            networkEvents.insert(
                NetworkEvent(
                    timestamp: Date(),
                    method: method,
                    url: url,
                    status: status,
                    durationMs: duration,
                    source: source
                ),
                at: 0
            )
            if networkEvents.count > 600 {
                networkEvents.removeLast(networkEvents.count - 600)
            }
            return
        }

        if kind == "console" {
            let level = payload["level"] as? String ?? "log"
            let message = payload["message"] as? String ?? ""

            consoleEvents.insert(
                ConsoleEvent(timestamp: Date(), level: level, message: message),
                at: 0
            )
            if consoleEvents.count > 600 {
                consoleEvents.removeLast(consoleEvents.count - 600)
            }
        }
    }

    func clearDevToolsData() {
        networkEvents.removeAll()
        consoleEvents.removeAll()
        blockedEvents.removeAll()
        extractedLinks.removeAll()
        pageHTML = ""
    }

    func refreshHTMLDump() {
        webView?.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let html = result as? String {
                    self.pageHTML = html
                } else if let error {
                    self.pageHTML = "Failed to load HTML: \(error.localizedDescription)"
                } else {
                    self.pageHTML = "No HTML available."
                }
            }
        }
    }

    func refreshLinkDump() {
        let script = "Array.from(document.querySelectorAll('a[href]')).map(function(a){ return a.href; })"
        webView?.evaluateJavaScript(script) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let links = result as? [String] {
                    self.extractedLinks = Array(Set(links)).sorted()
                } else if let error {
                    self.extractedLinks = ["Failed to extract links: \(error.localizedDescription)"]
                } else {
                    self.extractedLinks = []
                }
            }
        }
    }

    func toggleAds(_ enabled: Bool) {
        settings.blockAds = enabled
        persistAndRebuild(reloadCurrentPage: true)
    }

    func togglePopups(_ enabled: Bool) {
        settings.blockPopups = enabled
        persistSettingsOnly()
    }

    func toggleRedirects(_ enabled: Bool) {
        settings.blockRedirects = enabled
        persistSettingsOnly()
    }

    func toggleProxy(_ enabled: Bool) {
        settings.useProxy = enabled
        persistAndRebuild(reloadCurrentPage: true)
    }

    func toggleProxyRotation(_ enabled: Bool) {
        settings.rotateProxyOnFailure = enabled
        persistSettingsOnly()
    }

    func setHomepageToCurrent() {
        guard let url = currentURL else { return }
        settings.homepage = url.absoluteString
        persistSettingsOnly()
    }

    func updateNewTabStartPage(_ text: String) {
        if let normalized = normalizeURL(text) {
            settings.newTabStartPage = normalized.absoluteString
        }
        persistSettingsOnly()
    }

    func updateEmulation(_ profile: EmulationProfile) {
        settings.emulationProfile = profile
        persistAndRebuild(reloadCurrentPage: true)
    }

    func updateRestoreTabs(_ restore: Bool) {
        settings.restoreTabsOnLaunch = restore
        persistSettingsOnly()
        if !restore {
            Persistence.clearSavedTabs()
        } else {
            persistTabsIfNeeded()
        }
    }

    func openNewTab() {
        let url = normalizeURL(settings.newTabStartPage) ?? URL(string: "https://duckduckgo.com")!
        let tab = BrowserTab(title: "New Tab", urlString: url.absoluteString)
        tabs.append(tab)
        selectedTabID = tab.id
        queueLoad(url: url)
        persistTabsIfNeeded()
    }

    func selectTab(_ id: UUID) {
        guard id != selectedTabID else { return }
        selectedTabID = id
        guard let tab = tabs.first(where: { $0.id == id }), let url = URL(string: tab.urlString) else { return }
        queueLoad(url: url)
        persistTabsIfNeeded()
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll(where: { $0.id == id })

        if tabs.isEmpty {
            let freshURL = normalizeURL(settings.newTabStartPage) ?? URL(string: "https://duckduckgo.com")!
            let fresh = BrowserTab(urlString: freshURL.absoluteString)
            tabs = [fresh]
            selectedTabID = fresh.id
            queueLoad(url: freshURL)
        } else if selectedTabID == id {
            selectedTabID = tabs.last?.id
            if let selected = selectedTab, let url = URL(string: selected.urlString) {
                queueLoad(url: url)
            }
        }

        persistTabsIfNeeded()
    }

    func closeAllTabsAndStartFresh() {
        tabs.removeAll()
        let freshURL = normalizeURL(settings.newTabStartPage) ?? URL(string: "https://duckduckgo.com")!
        let fresh = BrowserTab(urlString: freshURL.absoluteString)
        tabs = [fresh]
        selectedTabID = fresh.id
        queueLoad(url: freshURL)
        persistTabsIfNeeded()
    }

    func addProxy(name: String, host: String, port: Int, type: ProxyKind, username: String, password: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Proxy \(proxies.count + 1)" : trimmedName

        let profile = ProxyProfile(
            name: finalName,
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            type: type,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        proxies.append(profile)
        if activeProxyID == nil {
            activeProxyID = profile.id
        }
        persistProxiesAndMaybeRebuild()
    }

    func removeProxy(at offsets: IndexSet) {
        let removedIDs = offsets.map { proxies[$0].id }
        proxies.remove(atOffsets: offsets)

        if let activeProxyID, removedIDs.contains(activeProxyID) {
            self.activeProxyID = proxies.first?.id
        }
        persistProxiesAndMaybeRebuild()
    }

    func setActiveProxy(_ id: UUID) {
        activeProxyID = id
        persistProxiesAndMaybeRebuild()
    }

    func rotateProxyAndRebuild() {
        guard !proxies.isEmpty else { return }

        let currentIndex: Int
        if let activeProxyID, let index = proxies.firstIndex(where: { $0.id == activeProxyID }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        let nextIndex = (currentIndex + 1) % proxies.count
        activeProxyID = proxies[nextIndex].id

        consoleEvents.insert(
            ConsoleEvent(
                timestamp: Date(),
                level: "info",
                message: "Proxy rotation switched to \(proxies[nextIndex].name)"
            ),
            at: 0
        )

        persistAndRebuild(reloadCurrentPage: true)
    }

    private var selectedTab: BrowserTab? {
        guard let selectedTabID else { return tabs.first }
        return tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first
    }

    private func updateSelectedTab(url: URL, title: String?) {
        guard let selectedTabID, let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        tabs[index].urlString = url.absoluteString
        tabs[index].lastUpdated = Date()
        if let title, !title.isEmpty {
            tabs[index].title = title
        } else if tabs[index].title == "New Tab" {
            tabs[index].title = url.host ?? "New Tab"
        }
        persistTabsIfNeeded()
    }

    private func persistTabsIfNeeded() {
        guard settings.restoreTabsOnLaunch else { return }
        Persistence.saveTabs(tabs)
        Persistence.saveSelectedTabID(selectedTabID)
    }

    private func normalizeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let explicit = URL(string: trimmed), explicit.scheme != nil {
            return explicit
        }

        if trimmed.contains("."), !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }

        return nil
    }

    func persistAndRebuild(reloadCurrentPage: Bool) {
        Persistence.saveSettings(settings)
        Persistence.saveProxies(proxies)
        Persistence.saveActiveProxyID(activeProxyID)
        persistTabsIfNeeded()

        if reloadCurrentPage, let currentURL {
            pendingLoadURL = currentURL
        }
        webViewIdentity = UUID()
    }

    private func persistSettingsOnly() {
        Persistence.saveSettings(settings)
    }

    private func persistProxiesAndMaybeRebuild() {
        Persistence.saveProxies(proxies)
        Persistence.saveActiveProxyID(activeProxyID)
        if settings.useProxy {
            if let currentURL {
                pendingLoadURL = currentURL
            }
            webViewIdentity = UUID()
        }
    }
}

enum Persistence {
    private static let settingsKey = "liquid.browser.settings"
    private static let proxiesKey = "liquid.browser.proxies"
    private static let activeProxyKey = "liquid.browser.activeProxy"
    private static let tabsKey = "liquid.browser.tabs"
    private static let selectedTabKey = "liquid.browser.selected.tab"

    static func loadSettings() -> BrowserSettings {
        guard
            let data = UserDefaults.standard.data(forKey: settingsKey),
            let settings = try? JSONDecoder().decode(BrowserSettings.self, from: data)
        else {
            return BrowserSettings()
        }
        return settings
    }

    static func saveSettings(_ settings: BrowserSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    static func loadProxies() -> [ProxyProfile] {
        guard
            let data = UserDefaults.standard.data(forKey: proxiesKey),
            let proxies = try? JSONDecoder().decode([ProxyProfile].self, from: data)
        else {
            return []
        }
        return proxies
    }

    static func saveProxies(_ proxies: [ProxyProfile]) {
        guard let data = try? JSONEncoder().encode(proxies) else { return }
        UserDefaults.standard.set(data, forKey: proxiesKey)
    }

    static func loadActiveProxyID() -> UUID? {
        guard
            let raw = UserDefaults.standard.string(forKey: activeProxyKey),
            let id = UUID(uuidString: raw)
        else {
            return nil
        }
        return id
    }

    static func saveActiveProxyID(_ id: UUID?) {
        UserDefaults.standard.set(id?.uuidString, forKey: activeProxyKey)
    }

    static func loadTabs() -> [BrowserTab] {
        guard
            let data = UserDefaults.standard.data(forKey: tabsKey),
            let tabs = try? JSONDecoder().decode([BrowserTab].self, from: data)
        else {
            return []
        }
        return tabs
    }

    static func saveTabs(_ tabs: [BrowserTab]) {
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        UserDefaults.standard.set(data, forKey: tabsKey)
    }

    static func clearSavedTabs() {
        UserDefaults.standard.removeObject(forKey: tabsKey)
        UserDefaults.standard.removeObject(forKey: selectedTabKey)
    }

    static func saveSelectedTabID(_ id: UUID?) {
        UserDefaults.standard.set(id?.uuidString, forKey: selectedTabKey)
    }

    static func loadSelectedTabID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: selectedTabKey) else {
            return nil
        }
        return UUID(uuidString: raw)
    }
}

struct RedirectBlocker {
    private let knownRedirectHosts: Set<String> = [
        "bit.ly",
        "t.co",
        "lnk.to",
        "ad.doubleclick.net",
        "googleadservices.com",
        "clickserve.dartsearch.net"
    ]

    private let redirectIndicators: [String] = [
        "redirect",
        "url=",
        "target=",
        "destination=",
        "next=",
        "continue="
    ]

    func shouldBlock(
        currentURL: URL?,
        targetURL: URL,
        navigationType: WKNavigationType,
        isMainFrame: Bool
    ) -> Bool {
        guard isMainFrame else { return false }
        guard targetURL.scheme == "http" || targetURL.scheme == "https" else { return false }

        let targetHost = targetURL.host?.lowercased() ?? ""
        if knownRedirectHosts.contains(targetHost) {
            return true
        }

        if navigationType == .linkActivated {
            return false
        }

        let sourceHost = currentURL?.host?.lowercased() ?? ""
        let hostChanged = !sourceHost.isEmpty && sourceHost != targetHost
        let lowerPath = targetURL.path.lowercased()
        let lowerQuery = targetURL.query?.lowercased() ?? ""

        let hasIndicator = redirectIndicators.contains(where: { token in
            lowerPath.contains(token) || lowerQuery.contains(token)
        })

        return hostChanged && hasIndicator
    }
}
