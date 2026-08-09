//
//  APIResponse.swift
//  WorkspaceBeta
//
//

enum ResponseStatus: Int, Decodable {
    case error
    case success
}

struct APIResponseStatus: Decodable {
    let success: ResponseStatus
}

struct APISuccessResponse<T: APIRequest>: Decodable {
    let data: T.Response
}

struct APIErrorResponseData: Decodable {
    let error: APIErrorResponse
}

struct APIErrorResponse: Decodable {
    let code: String
    let message: String
}

struct Throwable<T: Decodable>: Decodable {
    let result: Result<T, Error>

    init(from decoder: Decoder) throws {
        result = Result(catching: { try T(from: decoder) })
    }
}

