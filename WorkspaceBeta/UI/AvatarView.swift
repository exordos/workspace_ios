//
//  AvatarView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Kingfisher

struct AvatarView: View {

    let avatarUrn: String?
    let baseUrl: String
    let color: Int?
    let name: String
    let enhanceImageRequest: (URLRequest) -> URLRequest

    var body: some View {
        if let avatarUrn, let avatarUrlString = UrnParser.parse(urn: avatarUrn, baseUrl: baseUrl) {
            if avatarUrn.contains(":image:"), let avatarUrl = URL(string: avatarUrlString) {
                KFImage(avatarUrl)
                    .requestModifier(AnyModifier { request in
                        let modifiedRequest = enhanceImageRequest(request)
                        return modifiedRequest
                    })
                    .resizable()
                    .scaledToFill()
            } else {
                AsyncImage(url: URL(string: avatarUrlString)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray
                }
            }
        } else if let color {
            Color(hex: color)
        } else {
            Color.gray
        }
    }
}
