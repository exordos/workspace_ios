//
//  ChatEmptyView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct ChatEmptyView: View {
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Text("Сообщений нет")
            Spacer()
        }
    }
}

#Preview {
    ChatEmptyView()
}
