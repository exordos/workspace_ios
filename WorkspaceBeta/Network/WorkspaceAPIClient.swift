//
//  WorkspaceAPIClient.swift
//  WorkspaceBeta
//
//

import Combine
import Foundation

public protocol DataTaskProvider {
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher
}

extension URLSession: DataTaskProvider {}

class WorkspaceAPIClient: NSObject, APIClient {

    private(set) static var current: WorkspaceAPIClient!

    private var urlSession: URLSession!
    var userProfile: UserProfile?
    var baseAccessToken: String?
    var baseEmail: String?

    var accessToken: String? {
        return baseAccessToken ?? userProfile?.accessToken
    }

    @discardableResult
    override init() {

        super.init()
        Self.current = self
        urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    }

    func createPublisher<T: APIRequest>(for request: T) -> AnyPublisher<T.Response, Error> {
        do {
            let urlRequest = try prepare(request)
            let urlRequestWithHeaders = urlRequest.applying(httpHeaders(for: request))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = request.dateDecodingStrategy
            return urlSession.dataTaskPublisher(for: urlRequestWithHeaders)
                .tryMap { [request] result -> Data in
                    guard let response = result.response as? HTTPURLResponse else { throw HTTPError.statusCode }

                    switch response.statusCode {
                    case 200...299:
                        return result.data
                    case 401:
                        throw HTTPError.sessionExpired
                    default:
                        throw HTTPError.statusCode
                    }
                }
                .tryCatch { [request, weak self] error -> AnyPublisher<Data, Error> in
                    guard let self = self else { return Fail(error: APIError.decoding).eraseToAnyPublisher() }
                    if let httpError = error as? HTTPError, httpError == HTTPError.sessionExpired, !(request is UserLogInRequest) {
                        return self.refreshToken(for: urlRequestWithHeaders)
                    } else {
                        throw error
                    }
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

    func refreshToken(for request: URLRequest) -> AnyPublisher<Data, Error> {
        do {
            let refreshToken = userProfile?.refreshToken ?? ""
            let refreshRequest = RefreshTokenRequest(with: refreshToken)
            let urlRequest = try prepare(refreshRequest)
            let urlRequestWithHeaders = urlRequest.applying(httpHeaders(for: refreshRequest))

            return urlSession.dataTaskPublisher(for: urlRequestWithHeaders)
                .tryMap { [weak self] result -> RefreshTokenResponseData in
                    guard let response = result.response as? HTTPURLResponse,
                          (200...299).contains(response.statusCode)
                    else {
                        self?.userProfile?.clearData()
                        throw HTTPError.statusCode
                    }
                    return try JSONDecoder().decode(RefreshTokenResponseData.self, from: result.data)
                }
                .receive(on: DispatchQueue.main)
                .handleEvents(receiveOutput: { [weak self] refreshResponse in
                    self?.userProfile?.refreshToken = refreshResponse.refreshToken
                    self?.userProfile?.accessToken = refreshResponse.accessToken
                })
                .map { refreshResponse -> URLRequest in
                    var updatedRequest = request
                    updatedRequest = updatedRequest.applying([
                        "Authorization": "Bearer \(refreshResponse.accessToken)"
                    ])
                    return updatedRequest
                }
                .flatMap { [weak self] updatedRequest -> AnyPublisher<Data, Error> in
                    guard let self else {
                        return Fail(error: HTTPError.statusCode).eraseToAnyPublisher()
                    }
                    return urlSession.dataTaskPublisher(for: updatedRequest)
                        .tryMap { result -> Data in
                            guard let response = result.response as? HTTPURLResponse else {
                                throw HTTPError.statusCode
                            }
                            guard (200...299).contains(response.statusCode) else {
                                throw HTTPError.statusCode
                            }
                            return result.data
                        }
                        .handleEvents(receiveCompletion: { [weak self] completion in
                            if case .failure = completion {
                                self?.userProfile?.clearData()
                            }
                        })
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        } catch {
            userProfile?.clearData()
            return Fail(error: error).eraseToAnyPublisher()
        }
    }

    func uploadFile<T: APIRequest>(for request: T, data: Data, filename: String, mimeType: String) async throws -> T.Response {
        let urlRequest = try prepareUploadRequest(request, data: data, filename: filename, mimeType: mimeType)
        let urlRequestWithHeaders = urlRequest.applying(httpHeaders(for: request))

        let (responseData, response) = try await URLSession.shared.data(for: urlRequestWithHeaders)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.decoding
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.decoding
        }
        let decoded = try JSONDecoder().decode(T.Response.self, from: responseData)
        return decoded
    }

    func addBaseUrl(to avatarUrl: String) -> String {
        guard !avatarUrl.contains("https://"), let baseUrl = userProfile?.baseUrl else { return avatarUrl }
        return baseUrl + avatarUrl
    }

    func addHeaders(to request: URLRequest) -> URLRequest {
        return request.applying(authorizationHeaders)
    }

    private var task: URLSessionWebSocketTask?

    func createWebSocketTask() {
        let task = urlSession.webSocketTask(with: URL(string: "ws://workspace.exordos.com/api/messenger/ws?last_epoch_version=36")!, protocols: ["workspace.events.v1", "bearer.eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2NTc1MTksImlhdCI6MTc4MjY0MzYzMiwiYXV0aF90aW1lIjoxNzgyNjQzNjMyLCJqdGkiOiJiYjNkYzhhMi0xN2RmLTQyNDgtOGZiNy1iMTgxYWFiZTliYWIiLCJpc3MiOiJodHRwOi8vd29ya3NwYWNlLmV4b3Jkb3MuY29tOjgwL2FwaS9jb3JlL3YxL2lhbS9jbGllbnRzL2RlZmF1bHQvaWFtL2NsaWVudHMvMzg5ZGMyN2UtMDQwNy00ZDM4LWI3ODgtOTEyNWE4MTkxZDUyIiwiYXVkIjoiZXhvcmRvcyIsInN1YiI6Ijc0OWRiMTJiLTJlMzQtNDMwZi1hM2MzLTJmNDU5OTJiZjQ5ZSIsInR5cCI6IkJlYXJlciIsIm90cCI6ZmFsc2V9.fC8hCaKCCA4TyYDOpJrcGij6-ew4hF0_-VrtKkDij3PqBqDQyOHP3_N_t9L-8nUBMw9YAw_RqJlnWWXaLxfmvSqJ2-6OzyJk228vNudV5wy-0KQlPYBC6Z27AURlenXx57UjgZa1IUpX4eEmvsTj9VIWP4pb7udXnmVCVP1BZAUsmqZHWUmXdYSLeewFte_Hyhf8IT4Oaj5JGIpfLi9N2wt8R6z49qanoM0r4PUfJOKaPjgUFazq8_5hzhZLTpsECIetyGO82fBRoqBFyAdxNYHYdEaCUIZ_9HQQgWPVQGjAGcDEYY9yONRJlcZLGT60Ys8K7DMp7ksZn9D3ssNGHw"])
        self.task = task
        task.resume()

        receive()
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received: \(text)")
                case .data(let data):
                    print("Received \(data.count) bytes")
                @unknown default:
                    break
                }
                self.receive()
            case .failure(let error):
                print("Receive failed: \(error)")
            }
        }
    }
    private func httpHeaders<T: APIRequest>(for request: T) -> [String: String] {
        var headers: [String: String] = [:]
        headers["User-Agent"] = "Workspace/ios/\(Bundle.main.releaseVersionNumber)_\(Bundle.main.buildVersionNumber)"
        if request.requiresApiKey {
            authorizationHeaders.forEach {
                headers[$0.key] = $0.value
            }
        }
        request.additionalHeaders.forEach {
            headers[$0.key] = $0.value
        }
        return headers
    }

    private var authorizationHeaders: [String: String] {
        var headers: [String: String] = [:]
        if let accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        return headers
    }

    private func prepare<T: APIRequest>(_ request: T) throws -> URLRequest {
        switch request.method {
        case .get:
            return try prepareGetRequest(request)
        case .post, .put, .delete:
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
        guard let url = URL(string: try getURLString(from: request.resource, for: request)) else { throw APIError.encoding }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-type")
        let body = try preparePostJSONBody(with: request)
        urlRequest.httpBody = body
        return urlRequest
    }

    private func preparePostJSONBody<T: APIRequest>(with request: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.backendFormat)
        guard let body = try? encoder.encode(request) else { throw APIError.encoding }
        return body
    }

    private func prepareUploadRequest<T: APIRequest>(_ request: T, data: Data, filename: String, mimeType: String) throws -> URLRequest {
        guard let url = URL(string: try getURLString(from: request.resource, for: request)) else { throw APIError.encoding }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-type")
        let body = multipartBody(
            data: data,
            fieldName: "filename",
            filename: filename,
            mimeType: mimeType,
            boundary: boundary
        )
        urlRequest.httpBody = body
        return urlRequest
    }

    private func getURLString(from resource: ResourceType, for request: any APIRequest) throws -> String {
        switch resource {
        case .absolute(let string):
            return string
        case .relative(let string):
            guard let baseUrl = userProfile?.baseUrl else { throw APIError.encoding }
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
        let baseURL = try getURLString(from: request.resource, for: request)
        let delimiter = parameters.isEmpty ? "" : "?"
        guard let url = URL(string: "\(baseURL)\(delimiter)\(parameters)") else { throw (APIError.encoding) }
        return url
    }

    private func multipartBody(data: Data, fieldName: String, filename: String, mimeType: String, boundary: String) -> Data {
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
        )
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        return body
    }
}

enum HTTPParameter: Decodable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case stringArray([String])

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
        case .stringArray(let value):
            return value.joined(separator: ",")
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
        } else if let stringArrayValue = try? container.decode([String].self) {
            self = .stringArray(stringArrayValue)
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
            .map({ stringParameter(from: $1, with: $0) })
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
        else { throw APIError.encoding }
        return encodedParameters
    }

    private static func stringParameter(from parameter: HTTPParameter, with key: String) -> String {
        switch parameter {
        case let .stringArray(values):
            return values.map {
                "\(key)=\($0)"
            }.joined(separator: "&")
        default:
            return "\(key)=\(parameter.stringValue)"
        }
    }
}

enum HTTPError: LocalizedError {
    case statusCode
    case sessionExpired
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

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}


