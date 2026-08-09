//
//  EpochRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct EpochRequest: APIRequest {
    typealias Response = EpochResponseData
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/epoch/")
    }

    var method: HTTPMethod {
        return .get
    }
}

struct EpochRequestData: Decodable { }

struct EpochResponseData: Decodable {
    let epochVersion: String
    let epochGeneration: String

    enum CodingKeys: String, CodingKey {
        case epochVersion = "epoch_version"
        case epochGeneration = "epoch_generation"
    }
}
