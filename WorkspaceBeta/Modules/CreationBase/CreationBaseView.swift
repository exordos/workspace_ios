//
//  CreationBaseView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct CreationBaseView: View {

    @ObservedObject var viewModel: CreationBaseViewModel

    var body: some View {
        VStack(alignment: .leading) {
            createDirectStreamView
            createStreamView
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding(.horizontal, 12.0)
    }

    var createDirectStreamView: some View {
        HStack {
            Image("createDirectStream")
                .padding(.trailing, 8.0)
            Text("Начать чат")
                .font(.system(size: 14))
                .foregroundStyle(Color.textHeaders)
                .padding(.vertical, 8.0)

        }
        .onTapGesture {
            viewModel.onDirectTap()
        }
    }

    var createStreamView: some View {
        HStack {
            Image("createStream")
                .padding(.trailing, 8.0)
            Text("Создать стрим")
                .font(.system(size: 14))
                .foregroundStyle(Color.textHeaders)
                .padding(.vertical, 8.0)
        }
        .onTapGesture {
            viewModel.onStreamTap()
        }
    }
}
