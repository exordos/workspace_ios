import Foundation
import Testing
@testable import Workspace

struct TopicsRequestTests {
    @Test func topicListDecodesUnmutedAndDefaultTopics() throws {
        let response = """
        [
            {
                "uuid": "00000000-0000-4000-8000-000000000001",
                "stream_uuid": "00000000-0000-4000-8000-000000000003",
                "unread_count": 3,
                "active_unread_count": 1,
                "name": "Unmuted topic",
                "is_done": false,
                "is_default": false,
                "color": 0,
                "updated_at": "2026-01-01T12:00:00.123456+00:00",
                "notification_mode": "unmute"
            },
            {
                "uuid": "00000000-0000-4000-8000-000000000002",
                "stream_uuid": "00000000-0000-4000-8000-000000000003",
                "unread_count": 0,
                "active_unread_count": 0,
                "name": "Default topic",
                "is_done": false,
                "is_default": true,
                "color": 0,
                "updated_at": "2026-01-01T12:00:00Z",
                "notification_mode": "default"
            }
        ]
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = TopicsRequest().dateDecodingStrategy

        let topics = try decoder.decode(TopicsRequest.Response.self, from: Data(response.utf8))

        #expect(topics.map(\.notificationMode.rawValue) == ["unmute", "default"])
    }
}
