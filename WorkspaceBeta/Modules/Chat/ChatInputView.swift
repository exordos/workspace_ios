//
//  ChatInputView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import PhotosUI

struct ChatInputView: View {

    @Binding var typedMessage: String
    @State var selectedItem: PhotosPickerItem?
    @Binding var image: Image?
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            if let image {
                image
                    .resizable()
                    .frame(width: 100.0, height: 100.0)
            }
            HStack {
                Group {
                    PhotosPicker(selection: $selectedItem, matching: .images, preferredItemEncoding: .automatic) {
                        Image("attachFile")
                    }
                    TextField("", text: $typedMessage, axis: .vertical)
                        .lineLimit(4)
                }
                Button {
                    onSend()
                } label: {
                    ZStack {
                        Color.primary
                        Image("send")
                            .foregroundStyle(Color.onPrimary)
                    }
                    .frame(width: 46.0, height: 46.0)
                    .clipShape(RoundedRectangle(cornerRadius: 12.0))
                }
            }
            .padding(12.0)
            .background(Color.background)
            .clipShape(RoundedRectangle(cornerRadius: 12.0))
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let newItem {
                        if let newImage = try? await newItem.loadTransferable(type: Image.self) {
                            image = newImage
                        }
                    }
                }
            }
        }
        .background(Color.surface)
    }
}
