//
//  UrnParser.swift
//  WorkspaceBeta
//
//

import Foundation

struct UrnParser {
    static func parse(urn: String, baseUrl: String) -> String? {
        guard urn.starts(with: "urn") else { return nil }

        let parts = urn.replacingOccurrences(of: "urn:", with: "").split(separator: ":")

        guard parts.count == 2, let namespace = parts.first, let id = parts.last else { return nil }

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
