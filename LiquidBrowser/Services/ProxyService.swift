import Foundation
import Network
import WebKit

enum ProxyService {
    static func applyProxyIfPossible(_ profile: ProxyProfile, to configuration: WKWebViewConfiguration) {
        guard #available(iOS 17.0, *) else { return }
        guard let port = NWEndpoint.Port(rawValue: UInt16(profile.port)) else { return }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(profile.host),
            port: port
        )

        let proxyConfiguration = ProxyConfiguration(httpCONNECTProxy: endpoint)
        let dataStore = WKWebsiteDataStore.default()
        dataStore.proxyConfigurations = [proxyConfiguration]
        configuration.websiteDataStore = dataStore
    }
}
