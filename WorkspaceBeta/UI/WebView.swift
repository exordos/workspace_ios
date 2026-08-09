//
//  WebView.swift
//  WorkspaceBeta
//
//

import SwiftUI
@preconcurrency import WebKit
import Combine

class WebViewModel: ObservableObject {

    @Published var url: URL?
    @Published var isLoading: Bool = true
    @Published var isError: Bool = false
    @Published var shouldReload: Bool = false

    let onFinish: ((String) -> Void)

    init (url: URL?, onFinish: @escaping ((String) -> Void)) {
        self.url = url
        self.onFinish = onFinish
    }

    func reload() {
        shouldReload = true
        isError = false
        isLoading = true
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel

    let webView = WKWebView()

    func makeCoordinator() -> Coordinator {
        Coordinator(self.viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {

        private struct Constants {
            static let fullScreenErrorNegativePadding: CGFloat = -125.0
        }

        private var viewModel: WebViewModel

        init(_ viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.isLoading = false
            viewModel.isError = false
            viewModel.shouldReload = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            viewModel.isLoading = false
            viewModel.isError = true
            viewModel.shouldReload = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            viewModel.isLoading = false
            viewModel.isError = true
            viewModel.shouldReload = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
            print("URL: \(webView.url?.absoluteString ?? "N/A")")

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("START URL: \(webView.url?.absoluteString ?? "N/A")")
            if let url = webView.url, url.absoluteString.contains("/complete/oidc") {
                viewModel.onFinish(url.absoluteString)
            }
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            print("REDIRECT: \(webView.url?.absoluteString ?? "N/A")")
        }
    }

    func reload() {
        if let url = viewModel.url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<WebView>) {

        webView.navigationDelegate = context.coordinator

        if viewModel.shouldReload == true {
            reload()
        }
    }

    func makeUIView(context: Context) -> UIView {
        webView.navigationDelegate = context.coordinator

        if let url = viewModel.url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }
}

