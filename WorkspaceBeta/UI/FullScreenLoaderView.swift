//
//  FullScreenLoaderView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Combine

enum LoadingState {
    case initialized
    case loading
    case loaded
    case error
}

class LoadingTimer {

    let publisher = Timer.publish(every: 0.1, on: .main, in: .default)
    private var timerCancellable: Cancellable?

    func start() {
        self.timerCancellable = publisher.connect()
    }

    func cancel() {
        self.timerCancellable?.cancel()
    }
}

struct FullScreenLoaderView: View {

    @State private var index = 0

    private let images = (0...16).map { UIImage(named: "loader_\($0)")! }
    private var timer = LoadingTimer()

    var body: some View {

        return Image(uiImage: images[index])
            .resizable()
            .frame(width: 50, height: 50, alignment: .center)
            .onReceive(
                timer.publisher,
                perform: { _ in
                    self.index = self.index + 1
                    if self.index >= 7 { self.index = 0 }
                }
            )
            .onAppear { self.timer.start() }
            .onDisappear { self.timer.cancel() }
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

