//
//  KeyAnnouncedMessageView.swift
//  Workspace
//
//

import SwiftUI

struct KeyAnnouncedMessageView: View {

    let viewModel: ChatViewModel
    let payload: MessagePayload.KeyAnnounced

    var body: some View {
        Text("The security key was updated")
    }
}
