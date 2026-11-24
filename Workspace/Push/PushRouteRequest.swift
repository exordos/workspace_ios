import Foundation

struct PushRouteRequest<Result: Decodable>: APIRequest {
    typealias Response = Result
    typealias ResponseError = EmptyDecodableError

    let resource: ResourceType
    let method = HTTPMethod.get
    let dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.formatted(.backendFormat)

    func encode(to encoder: Encoder) throws {
        _ = encoder.container(keyedBy: CodingKeys.self)
    }

    enum CodingKeys: CodingKey {}
}
