//
//  KeyRequestMessageView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import SwiftData

struct KeyRequestMessageView: View {

    let viewModel: ChatViewModel
    let payload: MessagePayload.KeyRequest
    let authorUuid: String
    let messageUuid: String
    @Query var currentStreamArray: [StreamData]

    init(viewModel: ChatViewModel, payload: MessagePayload.KeyRequest, authorUuid: String, messageUuid: String, streamUuid: String) {
        self.viewModel = viewModel
        self.payload = payload
        self.authorUuid = authorUuid
        self.messageUuid = messageUuid

        let streamPredicate = #Predicate<StreamData> { stream in
            stream.uuid == streamUuid
        }
        _currentStreamArray = Query(filter: streamPredicate)
    }

    var body: some View {
        Text(attributedText)
            .multilineTextAlignment(.center)
            .environment(\.openURL, OpenURLAction { url in
                switch url.host {
                case "grant":
                    viewModel.sendGrant(for: payload, requestMessageUuid: messageUuid, currentStream: currentStreamArray.first)
                    return .handled
                case "reject":
                    viewModel.sendReject(for: payload, requestMessageUuid: messageUuid)
                    return .handled
                default:
                    return .discarded
                }
            })
    }

    private var attributedText: AttributedString {
        var text = AttributedString(viewModel.keyRequestMessage(for: payload, authorUuid: authorUuid))
        if let currentStream = currentStreamArray.first, currentStream.role == "owner", !viewModel.wasRequestFulfilled(payload: payload, messageUuid: messageUuid, streamUuid: viewModel.model.streamUuid, topicUuid: viewModel.model.topicUuid) {
            var grant = AttributedString(" Grant")
            grant.underlineStyle = .single
            grant.link = URL(string: "action://grant")

            let space = AttributedString(" ")

            var reject = AttributedString("Reject")
            reject.underlineStyle = .single
            reject.link = URL(string: "action://reject")

            text.append(grant)
            text.append(space)
            text.append(reject)
        }
        return text
    }
}
