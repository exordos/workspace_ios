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
    func uploadFile<T: APIRequest>(for request: T, data: Data, filename: String, mimeType: String, streamUuid: String?) async throws -> T.Response
    func createWebSocketTask(epochVersion: String, epochGeneration: String)
    func messages() -> AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> 
}

