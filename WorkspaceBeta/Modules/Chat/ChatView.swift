//
//  ChatView.swift
//  WorkspaceBeta
//
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
        VStack {
//            if viewModel.model.messages.isEmpty {
                ChatEmptyView()
//            } else {
//                ScrollView {
//                    ScrollViewReader { value in
//                        LazyVStack(spacing: 8.0) {
//                            ForEach(viewModel.model.messages) { message in
//                                ChatMessageView(message: message,
//                                                isCurrentUser: message.senderId == viewModel.model.currentUser.userId,
//                                                currentJitsiBaseUrl: viewModel.eventHadler.jitsiServerUrl,
//                                                enhanceImageUrl: viewModel.apiClient.addBaseUrl,
//                                                enhanceImageRequest: viewModel.apiClient.addHeaders,
//                                                onTapOnCallView: viewModel.didTapOnCallMessage)
//                                    .id(message.id)
//                            }
//                        }
//                        .onAppear { 
//                            value.scrollTo(viewModel.model.messages.last?.id, anchor: .bottom)
//                        }
//                        .onChange(of: viewModel.model.messages.count) { _, _ in
//                            value.scrollTo(viewModel.model.messages.last?.id, anchor: .bottom)
//                        }
//                        .padding(12.0)
//                    }
//                }
//                .background(Color.background)
//            }
//            ChatInputView(typedMessage: $viewModel.message, image: $viewModel.image, onSend: {
//                Task {
//                    viewModel.onSendButtonTapped
//                }
//            })
//                .padding(12.0)
//        }
//            .navigationTitle(viewModel.model.chatTitle)
//            .toolbar {
//                Button {
//                    viewModel.didTapOnCallButton()
//                } label: {
//                    Image(systemName: "phone.fill")
//                }
//            }
//            .fullScreenCover(item: $viewModel.jitsiNameItem) { item in
//                JitsiMeetViewWrapper(room: item.jitsiName) {
//
//                }
//            }
//            .onAppear {
//                viewModel.onAppear()
            }
    }
}
