import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let userContentController = configuration.userContentController
        userContentController.add(context.coordinator, name: DevToolsScript.bridgeName)
        userContentController.addUserScript(
            WKUserScript(
                source: DevToolsScript.source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        ContentBlockerService.shared.apply(
            to: userContentController,
            enabled: viewModel.settings.blockAds,
            exceptionDomains: viewModel.settings.adExceptionDomains
        )

        if let proxy = viewModel.activeProxy {
            ProxyService.applyProxyIfPossible(proxy, to: configuration)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = viewModel.settings.emulationProfile.userAgent

        viewModel.attach(webView: webView)

        if let pending = viewModel.consumePendingLoadURL() {
            webView.load(URLRequest(url: pending))
        } else if let home = URL(string: viewModel.settings.homepage) {
            webView.load(URLRequest(url: home))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let pending = viewModel.consumePendingLoadURL() {
            webView.load(URLRequest(url: pending))
        }

        if viewModel.consumeReloadFlag() {
            webView.reload()
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scrollView.delegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: DevToolsScript.bridgeName)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate {
        @MainActor private let viewModel: BrowserViewModel

        @MainActor
        init(viewModel: BrowserViewModel) {
            self.viewModel = viewModel
            super.init()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.recordNavigationStart()
                viewModel.syncNavigationState(from: webView)

                viewModel.networkEvents.insert(
                    NetworkEvent(
                        timestamp: Date(),
                        method: "NAV",
                        url: webView.url?.absoluteString ?? "",
                        status: "started",
                        durationMs: nil,
                        source: "navigation"
                    ),
                    at: 0
                )
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.recordNavigationFinish(webView: webView)
                viewModel.networkEvents.insert(
                    NetworkEvent(
                        timestamp: Date(),
                        method: "NAV",
                        url: webView.url?.absoluteString ?? "",
                        status: "finished",
                        durationMs: nil,
                        source: "navigation"
                    ),
                    at: 0
                )
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.recordNavigationFailure(webView: webView, error: error)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.recordNavigationFailure(webView: webView, error: error)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

            Task { @MainActor in
                let shouldBlock = viewModel.shouldBlockRedirect(
                    currentURL: webView.url,
                    targetURL: targetURL,
                    navigationType: navigationAction.navigationType,
                    isMainFrame: isMainFrame
                )
                decisionHandler(shouldBlock ? .cancel : .allow)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }

            Task { @MainActor in
                if viewModel.shouldBlockPopup(currentURL: webView.url, targetURL: navigationAction.request.url) {
                    viewModel.recordBlockedPopup(navigationAction.request.url)
                    return
                }

                if let popupURL = navigationAction.request.url {
                    viewModel.queueLoad(url: popupURL)
                }
            }

            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == DevToolsScript.bridgeName else { return }
            guard let payload = message.body as? [String: Any] else { return }
            Task { @MainActor in
                viewModel.handleDevToolsBridgeMessage(payload)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            Task { @MainActor in
                viewModel.handleScroll(offsetY: scrollView.contentOffset.y)
            }
        }
    }
}
