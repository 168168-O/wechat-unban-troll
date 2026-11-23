import SwiftUI
import WebKit

struct Entry: Identifiable {
    let id: String
    let name: String
    let url: String
    let note: String
}

struct OverseasView: View {
    @State private var urlString = "https://help.wechat.com/"
    @State private var shown = "https://help.wechat.com/"

    private let entries: [Entry] = [
        Entry(id: "help", name: "Help Center", url: "https://help.wechat.com/",
              note: "海外主通道，Account & Security → 登录申诉，表单里必填邮箱"),
        Entry(id: "site", name: "WeChat EN", url: "https://www.wechat.com/en/",
              note: "海外官网，底部 Help & Support 进同一套工单系统"),
        Entry(id: "faq", name: "FAQ", url: "https://help.wechat.com/cgi-bin/newreadtemplate?t=faq/index",
              note: "自助问答，找 Sign-in / Account restricted 条目")
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
                    ForEach(entries) { e in
                        Button(e.name) {
                            urlString = e.url
                            shown = e.url
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

            WebBox(urlString: shown).id(shown)

            Text(entries.first { $0.url == shown }?.note ?? "手输 URL 直接进")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(6)
        }
    }
}

struct WebBox: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        v.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        if let u = URL(string: urlString) { v.load(URLRequest(url: u)) }
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
