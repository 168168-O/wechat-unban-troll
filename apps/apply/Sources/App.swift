import SwiftUI
import WebKit
import UIKit

// ─────────────────────────────────────────────
// 解封申请 · 单页版
// 上半：全中文表单。中间：生成。底部：中国微信 / 国外微信 两个按钮。
// 点「申请」→ 打开官方页面 → 自动填入（国外自动用英文版）
// ─────────────────────────────────────────────

enum Channel: String, CaseIterable {
    case cn = "中国微信"
    case intl = "国外微信"

    var applyURL: String {
        switch self {
        case .cn:
            return "https://weixin110.qq.com/cgi-bin/mmspamsupport-bin/newredirectconfirmcgi?main_type=appeal"
        case .intl:
            return "https://help.wechat.com/cgi-bin/newreadtemplate?t=help_center/feedback_form&lang=en&Channel=WeChatOfficialWebsite"
        }
    }
}

enum Situation: String, CaseIterable, Identifiable {
    case login = "登录受限 / 环境异常"
    case report = "被他人举报 / 内容投诉"
    case market = "误判批量注册 / 营销"
    case stolen = "账号被盗后被封"
    case device = "换机换号后被拦"
    case pay = "微信支付受限"
    case cross = "跨境登录风控锁号"
    case nofriend = "没有好友能辅助验证"

    var id: String { rawValue }
}

struct ApplyForm {
    var wxid = ""
    var nickname = ""
    var cc = "+95"
    var phone = ""
    var email = ""
    var region = ""
    var location = ""
    var banText = ""
    var date = ""
    var device = "iPhone 12"
    var ios = "17.6"
    var scene: Situation = .cross
}

@main
struct ApplyApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @StateObject private var store = Store()
    @State private var channel: Channel = .intl
    @State private var showWeb = false
    @State private var outCN = ""
    @State private var outEN = ""
    @State private var kb: CGFloat = 0

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("账号资料（填一次，自动记住）")) {
                    field("微信号", $store.form.wxid)
                    field("微信昵称", $store.form.nickname)
                    HStack {
                        TextField("区号", text: $store.form.cc)
                            .frame(width: 70)
                            .keyboardType(.phonePad)
                        TextField("手机号（不加 0）", text: $store.form.phone)
                            .keyboardType(.phonePad)
                    }
                    field("收结果的邮箱", $store.form.email)
                        .keyboardType(.emailAddress)
                    field("注册地区", $store.form.region)
                    field("常驻登录地", $store.form.location)
                    field("封禁提示原文", $store.form.banText)
                    field("被封日期", $store.form.date)
                    field("手机型号", $store.form.device)
                    field("系统版本", $store.form.ios)
                }

                Section(header: Text("申请方式")) {
                    Picker("选一种", selection: $store.form.scene) {
                        ForEach(Situation.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section(header: Text("选择通道")) {
                    HStack(spacing: 10) {
                        channelButton(.cn)
                        channelButton(.intl)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(action: generate) {
                        Text("生成申请材料")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .disabled(store.form.wxid.isEmpty || store.form.phone.isEmpty)

                    Button(action: { showWeb = true }) {
                        Text("申请解封（自动填入 \(channel.rawValue)）")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 17, weight: .bold))
                    }
                    .disabled(outEN.isEmpty && outCN.isEmpty)
                }

                if !outCN.isEmpty {
                    Section(header: Text("中文内容（核对用）")) {
                        Text(outCN).font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("复制中文") { UIPasteboard.general.string = outCN }
                    }
                }

                if !outEN.isEmpty {
                    Section(header: Text("英文内容（国外通道提交这份）")) {
                        Text(outEN).font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("复制英文") { UIPasteboard.general.string = outEN }
                    }
                }

                Section { Color.clear.frame(height: kb) }
            }
            .navigationTitle("解封申请")
            .sheet(isPresented: $showWeb) {
                WebFill(channel: channel,
                        url: channel.applyURL,
                        email: store.form.email,
                        subject: subject(),
                        content: channel == .cn ? outCN : outEN)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { n in
                if let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    kb = max(0, UIScreen.main.bounds.height - f.origin.y)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                kb = 0
            }
        }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(title, text: text)
        }
    }

    private func channelButton(_ c: Channel) -> some View {
        Button {
            channel = c
        } label: {
            Text(c.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(channel == c ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(channel == c ? .white : .primary)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func subject() -> String {
        channel == .cn
            ? "申诉：账号 \(store.form.wxid) 登录受限，申请人工核验"
            : "Appeal: \(store.form.wxid) — login restriction, manual verification requested"
    }

    private func generate() {
        let f = store.form
        outCN = Texts.cn(f, subject: subject())
        outEN = Texts.en(f)
        store.save()
    }
}

// ───────────── 文案 ─────────────

enum Texts {

    static func cn(_ f: ApplyForm, subject: String) -> String {
        """
        \(subject)

        微信安全中心：

        我的微信账号 \(f.wxid)（昵称 \(f.nickname)，绑定手机 \(f.cc) \(f.phone)，注册地区 \(f.region)，常驻 \(f.location)）在 \(f.date) 登录时提示“\(f.banText)”，此后一直登不上。

        一、账号情况
        1. 这个号从注册至今一直由本人使用，设备固定为 \(f.device)（iOS \(f.ios)），没有外借、出租或买卖。
        2. 登录地点固定在 \(f.location)，用的是本人手机流量与家中 WiFi。
        3. 绑定手机 \(f.cc) \(f.phone) 在本人手上，可随时接收验证码。

        二、情况说明
        本人在 \(f.location) 长期生活工作，注册地区与号码归属地、登录地点不同，系统按跨境登录处理。这是本人在用的正常状态，不是账号买卖或代登录。

        三、申请事项
        1. 请人工核验账号归属，解除 \(f.wxid) 的登录限制。
        2. 验证码可发送至 \(f.cc) \(f.phone)。
        3. 处理结果请回信至 \(f.email)。

        四、可提供材料
        身份证件、本人名下话费账单、\(f.location) 居住证明、设备与登录设备截图。

        申请人：\(f.nickname)
        微信号：\(f.wxid)
        联系电话：\(f.cc) \(f.phone)
        联系邮箱：\(f.email)
        """
    }

    static func en(_ f: ApplyForm) -> String {
        """
        Dear WeChat Support Team,

        I am writing to appeal the login restriction on my WeChat account.

        ACCOUNT INFORMATION
        - WeChat name: \(f.nickname)
        - WeChat ID: \(f.wxid)
        - Linked mobile number: \(f.cc) \(f.phone)
        - Registered region: \(f.region)
        - Regular login location: \(f.location)
        - Device: \(f.device), iOS \(f.ios)
        - Contact email: \(f.email)

        WHAT HAPPENED
        On \(f.date) the account was blocked with the message "\(f.banText)". Since then I cannot sign in.

        WHY THIS IS A FALSE POSITIVE
        I live and work in \(f.location). My registered region, the country of my phone number and my login location differ, which the system reads as abnormal. For me it is normal: one person, one device, one city, for months. I have never sold, rented or shared the account.

        MY USE OF THE ACCOUNT
        1. Personal account: family chats, one work group and payments.
        2. No advertising, no mass messages, no investment offers.
        3. No bulk-add tools, bots, account farms, virtual numbers or modified clients.
        4. No complaint notice received before this restriction.

        WHAT I AM ASKING FOR
        1. Please verify ownership manually and lift the restriction on \(f.wxid).
        2. Please send the verification code to \(f.cc) \(f.phone).
        3. Please reply to \(f.email).

        ATTACHMENTS
        1. Screenshot of the restriction message
        2. Phone bill in my name showing \(f.cc) \(f.phone)
        3. Settings > General > About
        4. WeChat > Settings > Account Security > Devices

        Sincerely,
        \(f.nickname)
        WeChat ID \(f.wxid)
        """
    }
}

// ───────────── 存储 ─────────────

final class Store: ObservableObject {
    @Published var form = ApplyForm() {
        didSet { save() }
    }

    private let key = "apply.form.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let f = try? JSONDecoder().decode(Snapshot.self, from: d) {
            form = ApplyForm(wxid: f.wxid, nickname: f.nickname, cc: f.cc, phone: f.phone,
                        email: f.email, region: f.region, location: f.location,
                        banText: f.banText, date: f.date, device: f.device,
                        ios: f.ios, scene: Situation(rawValue: f.scene) ?? .cross)
        }
    }

    func save() {
        let c = Snapshot(wxid: form.wxid, nickname: form.nickname, cc: form.cc,
                        phone: form.phone, email: form.email, region: form.region,
                        location: form.location, banText: form.banText, date: form.date,
                        device: form.device, ios: form.ios, scene: form.scene.rawValue)
        if let d = try? JSONEncoder().encode(c) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    struct Snapshot: Swift.Codable {
        var wxid = "", nickname = "", cc = "+95", phone = "", email = ""
        var region = "", location = "", banText = "", date = ""
        var device = "iPhone 12", ios = "17.6", scene = "跨境登录风控锁号"
    }
}

// ───────────── 官方页面 + 自动填入 ─────────────

struct WebFill: View {
    let channel: Channel
    let url: String
    let email: String
    let subject: String
    let content: String

    @Environment(\.presentationMode) private var presentation

    var body: some View {
        NavigationView {
            WebBox(url: url, payload: payload)
                .navigationTitle(channel == .cn ? "中国微信 · 解封申请" : "国外微信 · 解封申请")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("关闭") { presentation.wrappedValue.dismiss() },
                    trailing: Button("重新填入") { /* 重载由 WebBox 内部按钮处理 */ }
                )
        }
    }

    private var payload: String {
        let d: [String: String] = ["email": email, "subject": subject, "body": content]
        let data = (try? JSONSerialization.data(withJSONObject: d, options: [])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

struct WebBox: UIViewRepresentable {
    let url: String
    let payload: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: fillJS(payload),
                                       injectionTime: .atDocumentEnd,
                                       forMainFrameOnly: false))
        cfg.userContentController = ucc
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        if let u = URL(string: url) { wv.load(URLRequest(url: u)) }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func fillJS(_ json: String) -> String {
        """
        (function(){
          var D = \(json);
          function set(el, v){
            if(!el || v === undefined) return;
            var p = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
            var d = Object.getOwnPropertyDescriptor(p, 'value');
            try { d.set.call(el, v); } catch(e) { el.value = v; }
            ['input','change','keyup','blur'].forEach(function(t){ el.dispatchEvent(new Event(t,{bubbles:true})); });
          }
          function lbl(el){
            var s = [el.name, el.id, el.placeholder, el.getAttribute('aria-label')].filter(Boolean).join(' ');
            var l = el.closest('label'); if(l) s += ' ' + l.textContent;
            var w = el.closest('div,li,tr,section,form'); if(w && w.textContent) s += ' ' + w.textContent.slice(0,200);
            return s.toLowerCase();
          }
          function fill(){
            var ins = Array.prototype.slice.call(document.querySelectorAll('input,textarea'))
              .filter(function(e){ return e.offsetParent !== null && e.type !== 'hidden' && !e.value; });
            var done = 0;
            ins.forEach(function(el){
              var k = lbl(el);
              if(/e-?mail/.test(k)) { set(el, D.email); done++; }
              else if(/subject|标题|主题/.test(k)) { set(el, D.subject); done++; }
              else if(/descript|detail|content|message|问题|描述|说明|申诉/.test(k) && el.tagName === 'TEXTAREA') { set(el, D.body); done++; }
            });
            if(!done){
              var ta = Array.prototype.slice.call(document.querySelectorAll('textarea'))
                .filter(function(e){ return e.offsetParent !== null; })
                .sort(function(a,b){ return (b.rows*b.cols)-(a.rows*a.cols); })[0];
              if(ta) set(ta, D.body);
            }
            var bar = document.createElement('div');
            bar.textContent = '已自动填入，核对后点提交';
            bar.style.cssText = 'position:fixed;left:12px;right:12px;bottom:16px;z-index:99999;background:#1f6feb;color:#fff;padding:10px;border-radius:10px;font:13px -apple-system;text-align:center';
            document.body.appendChild(bar);
            setTimeout(function(){ bar.remove(); }, 4000);
          }
          setTimeout(fill, 1200);
          setTimeout(fill, 3000);
        })();
        """
    }
}
