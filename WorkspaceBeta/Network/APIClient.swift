//
//  APIClient.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import Combine
import Foundation

protocol APIClient {
    func createPublisher<T: APIRequest>(for request: T) -> AnyPublisher<T.Response, Error>
}

