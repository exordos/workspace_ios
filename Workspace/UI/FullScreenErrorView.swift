//
//  FullScreenErrorView.swift
//  Workspace
//
//

import SwiftUI

struct FullScreenErrorViewModel {
    let actionToRepeat: () -> Void
}

struct FullScreenErrorView: View {

    let viewModel: FullScreenErrorViewModel

    var body: some View {
        VStack {
            Image("errorImage")
                .padding(.vertical, 20.0)
            Text("Что-то пошло не так")
                .foregroundStyle(Color.textHeaders)
                .font(.system(size: 16.0, weight: .medium))
            Text("Не удалось загрузить данные. Проверьте подключение к интернету и попробуйте ещё раз")
                .foregroundStyle(Color.textAdditional50)
                .font(.system(size: 14.0))
                .padding(.vertical, 20.0)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Повторить запрос", icon: "reload") {
                viewModel.actionToRepeat()
            }
            .padding(.vertical, 20.0)
        }
    }
}

struct FullScreenErrorViewModifier: ViewModifier {

    @Binding var errorViewModel: FullScreenErrorViewModel?

    func body(content: Content) -> some View {
        ZStack {
            content
            if let errorViewModel = errorViewModel {
                FullScreenErrorView(viewModel: errorViewModel)
                    .padding(.horizontal, 12.0)
            }
        }
    }
}

extension View {
    func fullScreenError(errorViewModel: Binding<FullScreenErrorViewModel?>) -> some View {
        modifier(FullScreenErrorViewModifier(errorViewModel: errorViewModel))
    }
}
