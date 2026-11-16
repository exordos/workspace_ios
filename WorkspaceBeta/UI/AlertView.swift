//
//  AlertView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct AlertView: View {
    private struct Appearance {
        static let cornerRadius: CGFloat = 12.0
        static let padding: EdgeInsets = .init(top: 8.0, leading: 16.0, bottom: 16.0, trailing: 8.0)
        static let textAdditionalPadding: CGFloat = 4.0
    }

    let errorText: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top) {
            Image("alertIcon")
            Text(errorText)
                .foregroundColor(Color.indicatorRed)
                .lineLimit(4)
                .font(.system(size: 14.0))
                .padding(.top, Appearance.textAdditionalPadding)
            Spacer()
        }
        .padding(Appearance.padding)
        .background(Color.alert)
        .clipShape(RoundedRectangle(cornerRadius: Appearance.cornerRadius))
    }
}

struct AlertErrorViewModifier: ViewModifier {

    private struct Constants {
        static let notificationDismissInteval: TimeInterval = 3.0
    }

    @Binding var errorText: LocalizedStringKey?

    func body(content: Content) -> some View {
        ZStack {
            content
            if let errorText = errorText {
                VStack {
                    AlertView(errorText: errorText)
                        .padding(12.0)
                    Spacer()
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Constants.notificationDismissInteval) {
                        if self.errorText != nil {
                            self.errorText = nil
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func alertError(errorText: Binding<LocalizedStringKey?>) -> some View {
        modifier(AlertErrorViewModifier(errorText: errorText))
    }
}
