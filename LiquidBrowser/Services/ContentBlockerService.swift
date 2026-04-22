import Foundation
import WebKit

final class ContentBlockerService {
    static let shared = ContentBlockerService()

    private init() {}

    private let listIdentifier = "liquid-browser-ad-block-rules"

    private let blockedHostFragments = [
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "adservice.google.com",
        "adnxs.com",
        "taboola.com",
        "outbrain.com",
        "zedo.com",
        "rubiconproject.com",
        "criteo.com",
        "adsystem.com",
        "tracking",
        "analytics"
    ]

    func apply(to userContentController: WKUserContentController, enabled: Bool) {
        userContentController.removeAllContentRuleLists()
        guard enabled else { return }

        let store = WKContentRuleListStore.default()
        store.lookUpContentRuleList(forIdentifier: listIdentifier) { [weak self] list, _ in
            if let list {
                userContentController.add(list)
                return
            }

            guard let self else { return }
            let json = self.makeRulesJSON()
            store.compileContentRuleList(
                forIdentifier: self.listIdentifier,
                encodedContentRuleList: json
            ) { compiledList, _ in
                guard let compiledList else { return }
                userContentController.add(compiledList)
            }
        }
    }

    private func makeRulesJSON() -> String {
        let rules: [[String: Any]] = blockedHostFragments.map { fragment in
            [
                "trigger": [
                    "url-filter": ".*\(escapeForRegex(fragment)).*"
                ],
                "action": [
                    "type": "block"
                ]
            ]
        }

        let data = (try? JSONSerialization.data(withJSONObject: rules, options: [])) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func escapeForRegex(_ text: String) -> String {
        NSRegularExpression.escapedPattern(for: text)
    }
}
