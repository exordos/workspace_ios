//
//  AvatarView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct AvatarView: View {

    let avatarUrn: String?
    let baseUrl: String
    let color: Int?
    let name: String

    var body: some View {
        if let avatarUrn, let avatarUrl = UrnParser.parse(urn: avatarUrn, baseUrl: baseUrl) {
            AsyncImage(url: URL(string: avatarUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray
            }
        } else if let color {
            Color(hex: color)
        } else {
            Color.gray
        }
    }
}
