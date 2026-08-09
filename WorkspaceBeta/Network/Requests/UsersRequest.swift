//
//  UsersRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct UsersRequest: APIRequest {
    typealias Response = [UserResponseData]
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/users/")
    }

    var method: HTTPMethod {
        return .get
    }
}

struct UserResponseData: Decodable, Hashable, Identifiable {
    var avatar: String
    var email: String?
    var firstName: String?
    var lastName: String?
    let uuid: String
    var status: String
    var statusEmoji: String?
    var statusText: String?
    let username: String

    var id: String {
        return uuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case username
        case avatar
        case status
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
    }

    var displayableName: String {
        var displayableName: String = ""

        if let firstName {
            displayableName += firstName
        }

        if let lastName {
            if !displayableName.isEmpty {
                displayableName += " "
            }
            displayableName += lastName
        }

        if displayableName.isEmpty {
            displayableName += username
        }

        return displayableName
    }
}
