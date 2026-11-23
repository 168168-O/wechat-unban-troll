import SwiftUI
import WebKit

struct Shortcut: Identifiable {
    let id: String
    let name: String
    let url: String
}

struct WebPanelView: View {
    @State private var urlString = "https://weixin110.qq.com/"
    @State private var shown = "https://weixin110.qq.com/"

    private let shortcuts: [Shortcut] = [
        Shortcut(id: "home", name: "安全中心", url: "https://weixin110.qq.com/"),
        Shortcut(id: "appeal", name: "解封申诉", url: "https://weixin110.qq.com/cgi-bin/mmspamsupport-bin/newredirectconfirmcgi?main_type=appeal"),
        Shortcut(id: "policy", name: "账保说明", url: "https://weixin110.qq.com/security/readtemplate?t=w_security_center/index"),
        Shortcut(id: "unblock", name: "自助解封", url: "https://support.weixin.qq.com/cgi-bin/mmsupport-bin/readtemplate?t=wechat_unblock")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                TextField("https://", text: $urlString)
                    .font(.system(size: 12))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                Button("打开") { shown = urlString }
                    .font(.system(size: 13))
            }
            .padding(8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shortcuts) { item in
                        Button(item.name) {
                            urlString = item.url
                            shown = item.url
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 40)

            WebBox(urlString: shown)
                .id(shown)
        }
    }
}

struct WebBox: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        if let u = URL(string: urlString) {
            v.load(URLRequest(url: u))
            LogStore.shared.log("WebView 打开 \(urlString)")
        }
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
