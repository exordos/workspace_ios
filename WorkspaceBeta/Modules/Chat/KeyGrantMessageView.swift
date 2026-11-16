//
//  KeyGrantMessageView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct KeyGrantMessageView: View {

    let viewModel: ChatViewModel
    let payload: MessagePayload.KeyGrant

    var body: some View {
        Text(viewModel.keyGrantMessage(for: payload))
    }
}
