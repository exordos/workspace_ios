//
//  APIRequest.swift
//  WorkspaceBeta
//
//

import Network
import Foundation

protocol APIRequest: Encodable {
    associatedtype Response: Decodable
    associatedtype ResponseError: Decodable, Error
    var resource: ResourceType { get }
    var method: HTTPMethod { get }
    var requiresApiKey: Bool { get }
    var shouldReturnUrl: Bool { get }
    var hasSessionCookie: Bool { get }
    var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy { get }
    var additionalHeaders: [String: String] { get }
}

extension APIRequest {

    typealias ResponseError = APIError

    var requiresApiKey: Bool {
        return true
    }

    var shouldReturnUrl: Bool {
        return false
    }

    var hasSessionCookie: Bool {
        return false
    }

    var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        return .iso8601
    }

    var additionalHeaders: [String: String] {
        return [:]
    }
}

enum ResourceType {
    case absolute(String)
    case relative(String)
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
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
