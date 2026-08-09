//
//  APIClient.swift
//  WorkspaceBeta
//
//

import Combine
import Foundation

protocol APIClient {
    func createPublisher<T: APIRequest>(for request: T) -> AnyPublisher<T.Response, Error>
    func addBaseUrl(to relativeUrl: String) -> String
    func addHeaders(to request: URLRequest) -> URLRequest
    func uploadFile<T: APIRequest>(for request: T, data: Data, filename: String, mimeType: String) async throws -> T.Response
}

