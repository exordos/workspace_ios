//
//  BadgeView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct BadgeView: View {

    let item: String
    let color: Color

    var body: some View {
        Text(item)
            .font(.system(size: 12.0))
            .foregroundStyle(Color.noticeOnBadge)
            .padding(.horizontal, 8.0)
            .padding(.vertical, 3.0)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 100.0))
    }
}

#Preview {
    BadgeView(item: "100", color: .green)
}
