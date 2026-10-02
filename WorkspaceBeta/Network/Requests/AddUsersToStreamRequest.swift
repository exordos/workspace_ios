//
//  AddUsersToStreamRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct AddUsersToStreamRequest: APIRequest {
    typealias Response = [AddUsersToStreamResponseData]
    typealias ResponseError = EmptyDecodableError


    let streamUuid: String
    let members: [String]

    enum CodingKeys: String, CodingKey {
        case members
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/streams/\(streamUuid)/actions/add_users/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with streamUuid: String, members: [String]) {
        self.streamUuid = streamUuid
        self.members = members
    }
}

struct AddUsersToStreamResponseData: Decodable { }


