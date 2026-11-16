//
//  EncryptedMessageView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import SwiftData

struct EncryptedMessageView: View {

    let viewModel: ChatViewModel
    let payload: MessagePayload.E2ee
    @Query var currentStreamArray: [StreamData]

    init(viewModel: ChatViewModel, payload: MessagePayload.E2ee, streamUuid: String) {
        self.viewModel = viewModel
        self.payload = payload

        let streamPredicate = #Predicate<StreamData> { stream in
            stream.uuid == streamUuid
        }
        _currentStreamArray = Query(filter: streamPredicate)
    }

    var body: some View {
        if let text = viewModel.decryptedMessage(from: payload, currentStream: currentStreamArray.first) {
            Text(text)
        } else {
            Text("Encrypted message")
        }
    }
}
