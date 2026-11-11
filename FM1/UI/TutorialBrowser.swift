import SwiftUI
import WebKit

/// In-app browser for the bundled web tutorial (`tutorial/` folder, static HTML).
/// Links to other websites open in Safari.
struct TutorialBrowser: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nav = TutorialNavigator()

    static var indexURL: URL? {
        Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "tutorial")
    }

    var body: some View {
        NavigationStack {
            Group {
                if let url = Self.indexURL {
                    TutorialWebView(index: url, nav: nav).ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView("Tutorial not found", systemImage: "book.closed",
                                           description: Text("The tutorial files are missing from this build."))
                }
            }
            .navigationTitle(nav.title.isEmpty ? "FM-1 Tutorial" : nav.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { nav.webView?.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!nav.canGoBack).accessibilityLabel("Back")
                    Button { nav.webView?.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!nav.canGoForward).accessibilityLabel("Forward")
                    Button { if let u = Self.indexURL { nav.webView?.loadFileURL(u, allowingReadAccessTo: u.deletingLastPathComponent()) } }
                        label: { Image(systemName: "house") }.accessibilityLabel("Tutorial home")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("tutorial.web.done")
                }
            }
        }
    }
}

final class TutorialNavigator: NSObject, ObservableObject, WKNavigationDelegate {
    weak var webView: WKWebView?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var title = ""

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { refresh(webView) }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { refresh(webView) }

    private func refresh(_ w: WKWebView) {
        canGoBack = w.canGoBack
        canGoForward = w.canGoForward
        title = w.title ?? ""
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, !url.isFileURL, url.scheme != "about" {
            // anything outside the bundled tutorial goes to Safari
            if action.navigationType == .linkActivated { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

private struct TutorialWebView: UIViewRepresentable {
    let index: URL
    let nav: TutorialNavigator

    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.navigationDelegate = nav
        w.allowsBackForwardNavigationGestures = true
        w.accessibilityIdentifier = "tutorial.web"
        nav.webView = w
        w.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        return w
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
