//
//  APIRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import Network
import Foundation

protocol APIRequest: Encodable {
    associatedtype Response: Decodable
    associatedtype ResponseError: Decodable, Error
    var resource: ResourceType { get }
    var method: HTTPMethod { get }
    var requiresApiKey: Bool { get }
}

extension APIRequest {

    typealias ResponseError = APIError

    var requiresApiKey: Bool {
        return true
    }
}

enum ResourceType {
    case absolute(String)
    case relative(String)
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

extension URLRequest {
    func applying(_ headers: [String: String]) -> URLRequest {
        var request = self
        request.applyHeaders(headers)
        return request
    }

    mutating func applyHeaders(_ headers: [String: String]) {
        headers.forEach { (key: String, value: String) in
            setValue(value, forHTTPHeaderField: key)
        }
    }
}
