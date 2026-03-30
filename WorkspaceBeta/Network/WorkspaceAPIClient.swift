//
//  WorkspaceAPIClient.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import Combine
import Foundation

public protocol DataTaskProvider {
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher
}

extension URLSession: DataTaskProvider {}

class WorkspaceAPIClient: APIClient {

    private(set) static var current: WorkspaceAPIClient!

    private let urlSession: DataTaskProvider
    var userProfile: UserProfile?

    @discardableResult
    init(with urlSession: DataTaskProvider) {
        self.urlSession = urlSession
        Self.current = self
    }

    func createPublisher<T: APIRequest>(for request: T) -> AnyPublisher<T.Response, Error> {
        do {
            let urlRequest = try prepare(request)
            let urlRequestWithHeaders = urlRequest.applying(httpHeaders(for: request))
            let decoder = JSONDecoder()
            return urlSession.dataTaskPublisher(for: urlRequestWithHeaders)
                .tryMap { result -> Data in
                    guard let response = result.response as? HTTPURLResponse,
                          response.statusCode == 200
                    else { throw HTTPError.statusCode }
                    return result.data
                }
                .flatMap { [weak self] data -> AnyPublisher<T.Response, Error> in
                    guard let self = self else { return Fail(error: APIError.decoding).eraseToAnyPublisher() }
                    return Just(data)
                        .decode(type: T.Response.self, decoder: decoder)
                        .map { response in
                            return response
                        }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }

    private func httpHeaders<T: APIRequest>(for request: T) -> [String: String] {
        var headers: [String: String] = [:]
        headers["User-Agent"] = "Workspace/ios/0.0.1"
        if request.requiresApiKey, let apiKey = userProfile?.apiKey, let email = userProfile?.userEmail {
            let authData = "\(email):\(apiKey)".data(using: String.Encoding.utf8)!
            let base64AuthString = authData.base64EncodedString()
            headers["Authorization"] = "Basic \(base64AuthString)"
        }
        return headers
    }

    private func prepare<T: APIRequest>(_ request: T) throws -> URLRequest {
        switch request.method {
        case .get:
            return try prepareGetRequest(request)
        case .post:
            return try preparePostRequest(request)
        }
    }

    private func prepareGetRequest<T: APIRequest>(_ request: T) throws -> URLRequest {
        let url = try endpoint(for: request)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        return urlRequest
    }

    private func preparePostRequest<T: APIRequest>(_ request: T) throws -> URLRequest {
        guard let url = URL(string: try getURLString(from: request.resource)) else { throw APIError.encoding }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-type")
        let body = try urlQueryBody(with: request)
        urlRequest.httpBody = body
        return urlRequest
    }

    private func getURLString(from resource: ResourceType) throws -> String {
        guard let baseUrl = userProfile?.baseUrl else { throw APIError.encoding }
        switch resource {
        case .absolute(let string):
            return string
        case .relative(let string):
            return "\(baseUrl)\(string)"
        }
    }

    func urlQueryBody<T: APIRequest>(with request: T) throws -> Data {
        let encoder = JSONEncoder()
        guard let body = try? encoder.encode(request) else { throw APIError.encoding }

        guard let bodyDict = try? JSONSerialization.jsonObject(with: body) as? [String: String] else { return body }

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = bodyDict.map { URLQueryItem(name: $0.key, value: $0.value) }

        return bodyComponents.query?.data(using: .utf8) ?? body
    }

    private func endpoint<T: APIRequest>(for request: T) throws -> URL {
        let parameters = try URLQueryEncoder.encode(request)
        let baseURL = try getURLString(from: request.resource)
        let delimiter = baseURL.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(baseURL)\(delimiter)\(parameters)") else { throw (APIError.encoding) }
        return url
    }
}

enum HTTPParameter: Decodable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .int(let value):
            return String(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            throw APIError.decoding
        }
    }
}

class URLQueryEncoder {
    static func encode<T: Encodable>(_ encodee: T) throws -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(encodee) else { return "" }

        let parameters = try JSONDecoder().decode([String: HTTPParameter].self, from: data)
        guard let encodedParameters = parameters
            .map({ "\($0)=\($1.stringValue)" })
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
        else { throw APIError.encoding }
        return encodedParameters
    }
}

enum HTTPError: LocalizedError {
    case statusCode
}

enum ErrorCode: String, Decodable {
    case notAuthenticated = "NotAuthenticated"
}

enum APIError: Error {
    case decoding
    case encoding
    case sessionExpired
    case api(code: String, description: String)
}

struct EmptyDecodableError: Error, Decodable {

}




