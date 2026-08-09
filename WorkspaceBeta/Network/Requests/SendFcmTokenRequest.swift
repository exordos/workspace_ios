//
//  SendFcmTokenRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct SendFcmTokenRequest: APIRequest {
    typealias Response = SendFcmTokenResponseData
    typealias ResponseError = EmptyDecodableError

    let token: String

    var resource: ResourceType {
        return .relative("/users/me/android_gcm_reg_id")
    }

    var method: HTTPMethod {
        return .post
    }

    init(token: String) {
        self.token = token
    }
}

struct SendFcmTokenResponseData: Decodable {
}
