//
//  ChatView.swift
//  Workspace
//
//  
//

import SwiftUI
import SwiftData
import Combine
import JitsiMeetSDK
import GiphyUISDK

struct ChatView: View {

    @ObservedObject var viewModel: ChatViewModel
    @State var shouldPresentCallScene = false

    @Query var messages: [MessageData]
    @Query var currentStreamArray: [StreamData]

    init(viewModel: ChatViewModel, streamUuid: String, topicUuid: String) {
        self.viewModel = viewModel

        let messagesPredicate = #Predicate<MessageData> { message in
            message.stream?.uuid == streamUuid && message.topic?.uuid == topicUuid
        }
        _messages = Query(filter: messagesPredicate, sort: \MessageData.createdAt)

        let streamPredicate = #Predicate<StreamData> { stream in
            stream.uuid == streamUuid
        }
        _currentStreamArray = Query(filter: streamPredicate)
    }

    var body: some View {
        VStack {
            if messages.isEmpty {
                ChatEmptyView()
            } else {
                ScrollView {
                    ScrollViewReader { value in
                        LazyVStack(spacing: 8.0) {
                            ForEach(messages) { message in
                                ChatMessageView(viewModel: viewModel,
                                                message: message,
                                                isCurrentUser: message.isOwn,
                                                currentJitsiBaseUrl: viewModel.eventHandler.meetUrl,
                                                enhanceImageUrl: viewModel.apiClient.addBaseUrl,
                                                enhanceImageRequest: viewModel.apiClient.addHeaders,
                                                onTapOnCallView: viewModel.didTapOnCallMessage)
                                    .id(message.uuid)
                                    .contextMenu(
                                        ContextMenu {
                                            ControlGroup {
                                                Button {

                                                } label: {
                                                    Text("👍")
                                                }
                                                Button {

                                                } label: {
                                                    Text("😀")
                                                }
                                                Button {

                                                } label: {
                                                    Text("❤️")
                                                }
                                            }
                                            Menu("Добавить реакцию") {
                                                ControlGroup {
                                                    Button {

                                                    } label: {
                                                        Text("✍️")
                                                    }
                                                    Button {

                                                    } label: {
                                                        Text("🫡")
                                                    }
                                                    Button {

                                                    } label: {
                                                        Text("😬")
                                                    }
                                                }
                                                ControlGroup {
                                                    Button {

                                                    } label: {
                                                        Text("🙏")
                                                    }
                                                    Button {

                                                    } label: {
                                                        Text("✋")
                                                    }
                                                    Button {

                                                    } label: {
                                                        Text("😅")
                                                    }
                                                }
                                            }
                                            Button {

                                            } label: {
                                                Text("Ответить")
                                            }
                                            if message.isOwn {
                                                Button {

                                                } label: {
                                                    Text("Редактировать")
                                                }
                                            }
                                        }
                                    )
                            }
                        }
                        .onAppear { 
                            value.scrollTo(messages.last?.uuid, anchor: .bottom)
                        }
                        .onChange(of: messages.count) { _, _ in
                            value.scrollTo(messages.last?.uuid, anchor: .bottom)
                        }
                        .padding(12.0)
                    }
                }
                .background(Color.background)
            }
            if viewModel.shouldRequestEncryptionKey(for: currentStreamArray.first) {
                PrimaryButton(title: "Запросить ключ") {
                    viewModel.sendEncryptedKeyRequest(with: currentStreamArray.first)
                }
                .padding(12.0)
            } else {
                ChatInputView(typedMessage: $viewModel.message, image: $viewModel.image, onSend: {
                    Task {
                        await viewModel.onSendButtonTapped(with: currentStreamArray.first)
                    }
                })
                .padding(12.0)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(currentStreamArray.first?.name ?? "Диалог")
        .toolbar {
            if let currentStream = currentStreamArray.first, !currentStream.hasEncryption {
                Button {
                    viewModel.didTapOnCallButton()
                } label: {
                    Image(systemName: "phone.fill")
                }
            }
            Button {
                viewModel.onInfoButtonTap()
            } label: {
                Image("streamInfo")
            }
        }
        .fullScreenCover(item: $viewModel.jitsiNameItem) { item in
            JitsiMeetViewWrapper(room: item.jitsiName) {

            }
        }
        .onAppear {
            viewModel.onAppear(shouldLoadMessages: true)
        }
    }
}
