//
//  UrnParser.swift
//  WorkspaceBeta
//
//

import Foundation

struct UrnParser {
    static func parse(urn: String, baseUrl: String) -> String? {
        guard urn.starts(with: "urn") else { return nil }

        let scheme: String
        let namespace: String
        let id: String
        let parameters: [String: String]

        let parts = urn.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let hierarchical = String(parts[0])
        let query = parts.count == 2 ? String(parts[1]) : ""
        let tokens = hierarchical.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard tokens.count == 3 else { return nil }
        scheme = String(tokens[0])
        namespace = String(tokens[1])
        id = String(tokens[2])
        var items: [String: String] = [:]
        if !query.isEmpty, let components = URLComponents(string: "?\(query)") {
            for item in components.queryItems ?? [] {
                items[item.name] = item.value ?? ""
            }
        }

        switch namespace {
        case "image":
            return "\(baseUrl)/api/workspace/v1/messenger/files/\(id)/actions/download"
        case "gravatar":
            return "https://secure.gravatar.com/avatar/\(id)?d=identicon"
        case "url":
            return String(id)
        default:
            return nil
        }
    }
}
