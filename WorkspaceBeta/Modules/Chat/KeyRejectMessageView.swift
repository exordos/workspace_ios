//
//  KeyRejectMessageView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct KeyRejectMessageView: View {

    let viewModel: ChatViewModel
    let payload: MessagePayload.KeyReject

    var body: some View {
        Text("Request rejected")
    }
}
