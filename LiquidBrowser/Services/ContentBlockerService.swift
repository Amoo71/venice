import Foundation
import WebKit

final class ContentBlockerService {
    static let shared = ContentBlockerService()

    private init() {}

    private let listIdentifierPrefix = "liquid-browser-ad-block-rules"

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

    func apply(to userContentController: WKUserContentController, enabled: Bool, exceptionDomains: [String]) {
        userContentController.removeAllContentRuleLists()
        guard enabled else { return }

        guard let store = WKContentRuleListStore.default() else { return }
        let listIdentifier = "\(listIdentifierPrefix)-\(identifierHash(for: exceptionDomains))"
        store.lookUpContentRuleList(forIdentifier: listIdentifier) { [weak self] list, _ in
            if let list {
                userContentController.add(list)
                return
            }

            guard let self else { return }
            let json = self.makeRulesJSON(exceptionDomains: exceptionDomains)
            store.compileContentRuleList(
                forIdentifier: listIdentifier,
                encodedContentRuleList: json
            ) { compiledList, _ in
                guard let compiledList else { return }
                userContentController.add(compiledList)
            }
        }
    }

    private func makeRulesJSON(exceptionDomains: [String]) -> String {
        let blockRules: [[String: Any]] = blockedHostFragments.map { fragment in
            [
                "trigger": [
                    "url-filter": ".*\(escapeForRegex(fragment)).*"
                ],
                "action": [
                    "type": "block"
                ]
            ]
        }

        let allowRules: [[String: Any]] = exceptionDomains.compactMap { domain in
            let normalized = normalizeDomain(domain)
            guard !normalized.isEmpty else { return nil }
            return [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": [
                        "*\(normalized)"
                    ]
                ],
                "action": [
                    "type": "ignore-previous-rules"
                ]
            ]
        }

        let rules = blockRules + allowRules

        let data = (try? JSONSerialization.data(withJSONObject: rules, options: [])) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func escapeForRegex(_ text: String) -> String {
        NSRegularExpression.escapedPattern(for: text)
    }

    private func normalizeDomain(_ text: String) -> String {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.hasPrefix("*.") {
            return String(lower.dropFirst(2))
        }
        if lower.hasPrefix(".") {
            return String(lower.dropFirst())
        }
        return lower
    }

    private func identifierHash(for exceptionDomains: [String]) -> String {
        let joined = exceptionDomains
            .map { normalizeDomain($0) }
            .sorted()
            .joined(separator: "|")

        let scalar = joined.unicodeScalars.reduce(UInt32(0)) { partial, scalar in
            partial &+ scalar.value
        }
        return String(scalar, radix: 16)
    }
}
