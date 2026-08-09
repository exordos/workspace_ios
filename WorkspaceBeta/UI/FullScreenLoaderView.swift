//
//  FullScreenLoaderView.swift
//  WorkspaceBeta
//
//

import SwiftUI

enum LoadingState {
    case initialized
    case loading
    case loaded
    case error
}

struct FullScreenLoaderView: View {

    @State var isAnimating = false
    @State var showLoader = false

    var body: some View {
        ZStack {
            if showLoader {
                Image("loader")
                    .rotationEffect(Angle(radians: self.isAnimating ? 2 * .pi : .zero))
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: UUID()
                    )
                    .onAppear {
                        self.isAnimating = true
                    }
            }
            Color.gray.opacity(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.showLoader = true
            }
        }
        .ignoresSafeArea(.all)
    }
}

struct LoadingView: ViewModifier {

    var isLoading: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
            if isLoading {
                FullScreenLoaderView()
            }
        }
    }
}

extension View {
    func showLoader(_ isLoading: Bool) -> some View {
        modifier(LoadingView(isLoading: isLoading))
    }
}

struct FullScreenLoaderView_Previews: PreviewProvider {
    static var previews: some View {
        FullScreenLoaderView()
            .previewLayout(.fixed(width: 200.0, height: 200.0))
    }
}

