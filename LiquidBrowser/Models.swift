import Foundation

enum ProxyKind: String, CaseIterable, Codable, Identifiable {
    case httpConnect = "HTTP CONNECT"
    case https = "HTTPS"
    case socks5 = "SOCKS5"

    var id: String { rawValue }
}

enum EmulationProfile: String, CaseIterable, Codable, Identifiable {
    case iphone = "iPhone"
    case macOS = "macOS Safari"
    case android = "Android Chrome"
    case iPad = "iPad Safari"

    var id: String { rawValue }

    var userAgent: String {
        switch self {
        case .iphone:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        case .macOS:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        case .android:
            return "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.60 Mobile Safari/537.36"
        case .iPad:
            return "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        }
    }
}

struct BrowserTab: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var urlString: String
    var lastUpdated: Date

    init(id: UUID = UUID(), title: String = "New Tab", urlString: String, lastUpdated: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.lastUpdated = lastUpdated
    }
}

struct ProxyProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var type: ProxyKind
    var username: String
    var password: String

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        type: ProxyKind,
        username: String = "",
        password: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.type = type
        self.username = username
        self.password = password
    }
}

struct BrowserSettings: Codable {
    var blockAds: Bool = true
    var blockPopups: Bool = true
    var blockRedirects: Bool = true
    var useProxy: Bool = false
    var rotateProxyOnFailure: Bool = true
    var homepage: String = "https://duckduckgo.com"
    var newTabStartPage: String = "https://duckduckgo.com"
    var restoreTabsOnLaunch: Bool = true
    var emulationProfile: EmulationProfile = .iphone
}

struct NetworkEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let url: String
    let status: String
    let durationMs: Int?
    let source: String
}

struct ConsoleEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let message: String
}

enum DevToolsTab: String, CaseIterable, Identifiable {
    case network = "Network"
    case console = "Console"
    case links = "Links"
    case html = "HTML"

    var id: String { rawValue }
}
