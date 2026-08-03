//
//  JitsiMeetViewWrapper.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 29.03.2026.
//

import SwiftUI
import UIKit
import JitsiMeetSDK


struct JitsiMeetViewWrapper: UIViewRepresentable {
    let serverURL: URL
    let room: String
    let readyToClose: () -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIView(context: Context) -> JitsiMeetView {
        let view = JitsiMeetView()
        view.delegate = context.coordinator

        let options = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.serverURL = serverURL
            builder.room = room
            builder.setFeatureFlag("welcomepage.enabled", withValue: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            view.join(options)
        }
        return view
    }

    func updateUIView(_ uiView: JitsiMeetView, context: Context) { }

    static func dismantleUIView(_ uiView: JitsiMeetView, coordinator: Coordinator) {
        uiView.hangUp()
    }

    class Coordinator: NSObject, JitsiMeetViewDelegate {
        var parent: JitsiMeetViewWrapper

        init(_ parent: JitsiMeetViewWrapper) {
            self.parent = parent
        }

        func ready(toClose data: [AnyHashable : Any]!) {
            DispatchQueue.main.async {
                self.parent.readyToClose()
            }
        }
    }
}
