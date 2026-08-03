import Foundation

nonisolated struct WorkspaceCall: Equatable, Identifiable, Sendable {
    let serverURL: URL
    let room: String

    var id: String { "\(serverURL.absoluteString)#\(room)" }

    var invitationURL: URL? {
        serverURL.appending(path: room)
    }

    static func parse(_ text: String, meetURL: URL?) -> WorkspaceCall? {
        guard let meetURL,
              let invitationURL = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              invitationURL.scheme?.lowercased() == meetURL.scheme?.lowercased(),
              invitationURL.host?.lowercased() == meetURL.host?.lowercased(),
              invitationURL.port == meetURL.port
        else { return nil }

        let basePath = meetURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let invitationPath = invitationURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let room: String
        if basePath.isEmpty {
            room = invitationPath
        } else {
            let prefix = basePath + "/"
            guard invitationPath.hasPrefix(prefix) else { return nil }
            room = String(invitationPath.dropFirst(prefix.count))
        }

        guard !room.isEmpty, !room.contains("/") else { return nil }
        return WorkspaceCall(serverURL: meetURL, room: room)
    }
}

nonisolated enum WorkspaceCallRoomNameGenerator {
    private static let adjectives = [
        "amber", "brisk", "calm", "clever", "daring", "eager", "fancy", "gentle",
        "jolly", "kind", "lucky", "merry", "nimble", "proud", "quick", "sunny",
        "tidy", "vivid", "witty", "zesty",
    ]
    private static let qualifiers = [
        "blue", "crimson", "golden", "green", "indigo", "ivory", "jade", "lavender",
        "orange", "pearl", "ruby", "silver", "teal", "violet",
    ]
    private static let nouns = [
        "anchor", "badger", "beacon", "comet", "dolphin", "falcon", "forest", "harbor",
        "lantern", "meadow", "otter", "panda", "river", "rocket", "sparrow", "summit",
        "tiger", "valley", "willow", "zephyr",
    ]

    static func generate() -> String {
        let adjective = adjectives.randomElement() ?? "calm"
        let qualifier = qualifiers.randomElement() ?? "blue"
        let noun = nouns.randomElement() ?? "harbor"
        return adjective + qualifier.capitalized + noun.capitalized
    }
}
