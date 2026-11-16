//
//  ChatMessageView.swift
//  Workspace
//
//

import SwiftUI
import Kingfisher

enum MessagePart: Hashable {
    case image(fileName: String, urn: String)
    case file(fileName: String, uuid: String)
    case quote(displayName: String, uuid: String, text: String)
    case plainText(text: String)
}

struct ChatMessageView: View {
    let viewModel: ChatViewModel
    let message: MessageData
    let isCurrentUser: Bool
    let currentJitsiBaseUrl: String
    let enhanceImageUrl: (String) -> String
    let enhanceImageRequest: (URLRequest) -> URLRequest
    let onTapOnCallView: (String) -> Void

    var body: some View {
        switch message.payload {
        case let .markdown(markdownPayload):
            MarkdownMessageView(viewModel: viewModel,
                                payload: markdownPayload,
                                author: message.author,
                                isOwn: message.isOwn,
                                createdAt: message.createdAt,
                                currentJitsiBaseUrl: currentJitsiBaseUrl,
                                enhanceImageUrl: enhanceImageUrl,
                                enhanceImageRequest: enhanceImageRequest,
                                onTapOnCallView: onTapOnCallView)
        case let .e2ee(e2eePayload):
            EncryptedMessageView(viewModel: viewModel, payload: e2eePayload, streamUuid: viewModel.model.streamUuid)
        case let .keyRequest(keyRequestPayload):
            KeyRequestMessageView(viewModel: viewModel, payload: keyRequestPayload, authorUuid: message.authorUuid, messageUuid: message.uuid, streamUuid: viewModel.model.streamUuid)
        case let .keyGrant(keyGrantPayload):
            KeyGrantMessageView(viewModel: viewModel, payload: keyGrantPayload)
        case let .keyReject(keyRejectPayload):
            KeyRejectMessageView(viewModel: viewModel, payload: keyRejectPayload)
        case let .keyAnnounced(keyAnnouncedPayload):
            KeyAnnouncedMessageView(viewModel: viewModel, payload: keyAnnouncedPayload)
        case .undefined:
            Text("Данное сообщение не поддерживается в Workspace")
        }
    }
}

