//
//  SettingsItem.swift
//  Workspace
//
//

import SwiftUI

struct SettingsItem: View {

    let imageName: String
    let title: String
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(imageName)
                    .padding(EdgeInsets(top: 6.0, leading: 0.0, bottom: 6.0, trailing: 8.0))
                Text(title)
                    .foregroundStyle(Color.textHeaders)
                    .font(.system(size: 14))
            }
            Divider()
                .background(Color.line10)
        }
        .onTapGesture {
            onTap()
        }
    }
}
