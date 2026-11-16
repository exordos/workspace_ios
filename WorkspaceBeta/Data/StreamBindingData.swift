//
//  StreamBindingData.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftData

@Model
class StreamBindingData {
    @Attribute(.unique) var uuid: String
    var role: String

    var stream: StreamData?
    var user: UserData?

    init(uuid: String, role: String, stream: StreamData, user: UserData) {
        self.uuid = uuid
        self.role = role
        self.stream = stream
        self.user = user
    }
}
