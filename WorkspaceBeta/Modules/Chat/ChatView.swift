//
//  ChatView.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI
import Combine
import JitsiMeetSDK
import GiphyUISDK

struct ChatView: View {

    @ObservedObject var viewModel: ChatViewModel
    @State var shouldPresentCallScene = false

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .navigationTitle(viewModel.model.chatTitle)
            .toolbar {
                Button {
                    viewModel.sendMessage(with: "https://meet.genesis-core.tech/veryWeirdName")
                    shouldPresentCallScene = true
                } label: {
                    Image(systemName: "phone.fill")
                }
            }
            .fullScreenCover(isPresented: $shouldPresentCallScene) {
                JitsiMeetViewWrapper(room: "veryWeirdName") {

                }
            }
    }
}
