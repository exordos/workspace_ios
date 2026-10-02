//
//  DraftsRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct DraftsRequest: APIRequest {
    typealias Response = [DraftResponseData]
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/drafts/")
    }

    var method: HTTPMethod {
        return .get
    }
}

struct DraftResponseData: Decodable, Hashable {
    let uuid: String
    var streamUuid: String
    var topicUuid: String
    var payload: MessageResponsePayload
    let updatedAt: Date
    var revision: Int

    enum CodingKeys: String, CodingKey {
        case uuid
        case streamUuid = "stream_uuid"
        case topicUuid = "topic_uuid"
        case payload
        case updatedAt = "updated_at"
        case revision
    }
}
