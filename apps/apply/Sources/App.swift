import SwiftUI
import WebKit
import AVFoundation
import PhotosUI

// ─────────────────────────────────────────────
// 解封申请 · 三屏版（iPhone 12 / iOS 15.3）
// 1 屏 选中国还是国外    2 屏 填三格       3 屏 一个大按钮
// 每屏有中文语音朗读，字号大，一屏一个动作
// ─────────────────────────────────────────────

enum Side: String {
    case cn, intl

    var title: String { self == .cn ? "中国微信" : "国外微信" }
    var hint: String { self == .cn ? "手机号是 +86 开头" : "手机号是 +65、+95 这种" }
    var icon: String { self == .cn ? "message.fill" : "globe" }
    var color: Color { self == .cn ? Color(red: 0.02, green: 0.70, blue: 0.36) : Color(red: 0.12, green: 0.44, blue: 0.92) }
    var url: String {
        self == .cn
            ? "https://weixin110.qq.com/cgi-bin/mmspamsupport-bin/newredirectconfirmcgi?main_type=appeal"
            : "https://help.wechat.com/cgi-bin/newreadtemplate?t=help_center/feedback_form&lang=en&Channel=WeChatOfficialWebsite"
    }
}

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    func say(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        u.rate = 0.45
        u.pitchMultiplier = 1.0
        synth.speak(u)
    }
}

final class Model: ObservableObject {
    @Published var side: Side? = nil
    @Published var wxid = ""
    @Published var phone = ""
    @Published var cc = "+95"
    @Published var email = ""
    @Published var shot: UIImage? = nil
    @Published var step = 0

    init() {
        let d = UserDefaults.standard
        wxid = d.string(forKey: "wxid") ?? ""
        phone = d.string(forKey: "phone") ?? ""
        cc = d.string(forKey: "cc") ?? "+95"
        email = d.string(forKey: "email") ?? ""
        if let s = d.string(forKey: "side"), let v = Side(rawValue: s) { side = v }
    }

    func save() {
        let d = UserDefaults.standard
        d.set(wxid, forKey: "wxid")
        d.set(phone, forKey: "phone")
        d.set(cc, forKey: "cc")
        d.set(email, forKey: "email")
        d.set(side?.rawValue ?? "", forKey: "side")
    }

    var canGoNext: Bool {
        switch step {
        case 0: return side != nil
        case 1: return !wxid.isEmpty && !phone.isEmpty && !email.isEmpty
        default: return true
        }
    }
}

@main
struct ApplyApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @StateObject private var m = Model()
    @State private var showWeb = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                if m.step == 0 { ChannelStep(m: m) }
                else if m.step == 1 { FormStep(m: m) }
                else { ReadyStep(m: m, onApply: { m.save(); showWeb = true }) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showWeb) {
            WebFill(side: m.side ?? .intl,
                    url: (m.side ?? .intl).url,
                    email: m.email,
                    subject: subjectText(),
                    content: bodyText())
        }
        .onAppear { speakStep() }
    }

    private var header: some View {
        HStack {
            Text("解封申请")
                .font(.system(size: 26, weight: .bold))
            Spacer()
            Text("\(m.step + 1)/3")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if m.step > 0 {
                Button {
                    m.step -= 1
                    speakStep()
                } label: {
                    Text("上一步")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 64)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                }
            }
            Button {
                Speaker.shared.say(stepSpeech())
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 24))
                    .frame(width: 64, height: 64)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func stepSpeech() -> String {
        switch m.step {
        case 0: return "第一步。你的微信是用哪个手机号注册的。中国手机号点左边，国外手机号点右边。"
        case 1: return "第二步。填三个格子：微信号、手机号、收结果的邮箱。填完点下一步。"
        default: return "第三步。点下面的大按钮，我会打开官方网站，把内容自动填好。你核对一下，点提交。"
        }
    }

    private func speakStep() { Speaker.shared.say(stepSpeech()) }

    private func subjectText() -> String {
        m.side == .cn
            ? "申诉：账号 \(m.wxid) 登录受限，申请人工核验"
            : "Appeal: \(m.wxid) — login restriction, manual verification requested"
    }

    private func bodyText() -> String {
        let wxid = m.wxid.isEmpty ? "[微信号]" : m.wxid
        let phone = m.phone.isEmpty ? "[手机号]" : m.phone
        let mail = m.email.isEmpty ? "[邮箱]" : m.email
        if m.side == .cn {
            return """
            微信安全中心：

            我的微信账号 \(wxid)，绑定手机 \(m.cc) \(phone)，现在被限制登录，自助解封要求好友辅助验证，我这边没有可以配合的好友，走不下去，申请人工核验。

            一、账号情况
            1. 账号一直由本人使用，没有外借、出租或买卖。
            2. 绑定手机 \(m.cc) \(phone) 在本人手上，可随时接收验证码。
            3. 没有群发、没有加粉、没有使用任何外挂或改版客户端。

            二、申请事项
            1. 请人工核验账号归属，解除 \(wxid) 的登录限制。
            2. 验证码可发送至 \(m.cc) \(phone)。
            3. 处理结果请回信至 \(mail)。

            申请人：本人
            联系电话：\(m.cc) \(phone)
            """
        }
        return """
        Dear WeChat Support Team,

        I am writing to appeal the login restriction on my WeChat account.

        - WeChat ID: \(wxid)
        - Linked mobile number: \(m.cc) \(phone)
        - Contact email: \(mail)
        - Device: iPhone 12

        The account is locked by the cross-region login check and the self-unblock flow stops at friend verification, which I have no way to complete. I am asking for manual verification of ownership and for the restriction to be lifted.

        1. This is a personal account used by me only. It has never been sold, rented or shared.
        2. I have sent no advertising, no mass messages and no investment offers.
        3. I have not used bulk-add tools, bots, account farms, virtual numbers or modified clients.
        4. The number \(m.cc) \(phone) is in my hands and receives SMS at any time.

        Please verify ownership manually and lift the restriction on \(wxid). Please reply to \(mail).

        Sincerely,
        WeChat ID \(wxid)
        """
    }
}

// ───── 第 1 屏 ─────

struct ChannelStep: View {
    @ObservedObject var m: Model

    var body: some View {
        VStack(spacing: 18) {
            Text("你的微信，是用哪种手机号注册的？")
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            card(.cn)
            card(.intl)
            Spacer()
        }
        .onAppear { Speaker.shared.say("你的微信，是用哪种手机号注册的？中国号点左边，国外号点右边。") }
    }

    private func card(_ s: Side) -> some View {
        Button {
            m.side = s
            m.step = 1
            Speaker.shared.say(s == .cn ? "你选了国内。填微信号、手机号、邮箱。" : "你选了国外。填微信号、手机号、邮箱。")
        } label: {
            HStack(spacing: 18) {
                Image(systemName: s.icon)
                    .font(.system(size: 40, weight: .bold))
                    .frame(width: 74, height: 74)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(18)
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.title).font(.system(size: 28, weight: .bold))
                    Text(s.hint).font(.system(size: 17)).opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 22, weight: .bold)).opacity(0.7)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(m.side == s ? s.color : s.color.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(22)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ───── 第 2 屏 ─────

struct FormStep: View {
    @ObservedObject var m: Model
    @State private var showPicker = false
    @State private var kb: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                bigField("你的微信号", "填微信号，或者 wxid 开头那串", $m.wxid, .default)
                bigField("你的手机号", "只填数字，不要开头的 0", $m.phone, .phonePad)
                bigField("收结果的邮箱", "没有就填家人的", $m.email, .emailAddress)

                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 22))
                        Text(m.shot == nil ? "选一张封禁截图（可以不选）" : "已选截图，点这里可换")
                            .font(.system(size: 18, weight: .medium))
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }

                if let img = m.shot {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(height: 140)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                }

                Button {
                    m.save()
                    m.step = 2
                    Speaker.shared.say("第三步。点下面的大按钮。")
                } label: {
                    Text("下一步")
                        .font(.system(size: 22, weight: .bold))
                        .frame(maxWidth: .infinity).frame(height: 64)
                        .background(m.canGoNext ? Color(red: 0.02, green: 0.70, blue: 0.36) : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                }
                .disabled(!m.canGoNext)

                Color.clear.frame(height: kb)
            }
            .padding(.top, 10)
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $m.shot)
        }
        .onAppear { Speaker.shared.say("填三个格子。微信号、手机号、邮箱。") }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { n in
            if let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                kb = max(0, UIScreen.main.bounds.height - f.origin.y)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in kb = 0 }
    }

    private func bigField(_ title: String, _ hint: String, _ text: Binding<String>, _ kbType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    Speaker.shared.say(hint)
                } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 18))
                }
            }
            TextField(hint, text: text)
                .font(.system(size: 24))
                .keyboardType(kbType)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
        }
        .padding(.horizontal, 20)
    }
}

// ───── 第 3 屏 ─────

struct ReadyStep: View {
    @ObservedObject var m: Model
    var onApply: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 10) {
                row("通道", (m.side ?? .intl).title)
                row("微信号", m.wxid)
                row("手机号", m.cc + " " + m.phone)
                row("邮箱", m.email)
            }
            .padding(18)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(18)
            .padding(.horizontal, 20)

            Spacer()

            Button {
                onApply()
            } label: {
                VStack(spacing: 6) {
                    Text("生成并申请").font(.system(size: 28, weight: .bold))
                    Text("自动打开官网并填好").font(.system(size: 14)).opacity(0.9)
                }
                .frame(maxWidth: .infinity).frame(height: 110)
                .background(Color(red: 0.02, green: 0.70, blue: 0.36))
                .foregroundColor(.white)
                .cornerRadius(22)
                .padding(.horizontal, 20)
            }

            Text("进去以后核对一下，点页面上的提交按钮")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .onAppear { Speaker.shared.say("第三步。点下面的大绿按钮。进去以后点提交。") }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 16)).foregroundColor(.secondary)
            Spacer()
            Text(v.isEmpty ? "没填" : v).font(.system(size: 18, weight: .medium))
        }
    }
}

// ───── 选图 ─────

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 1
        let vc = PHPickerViewController(configuration: cfg)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coord { Coord(self) }

    final class Coord: NSObject, PHPickerViewControllerDelegate {
        private let parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
            item.loadObject(ofClass: UIImage.self) { img, _ in
                DispatchQueue.main.async { self.parent.image = img as? UIImage }
            }
        }
    }
}

// ───── 自动填入 ─────

struct WebFill: View {
    let side: Side
    let url: String
    let email: String
    let subject: String
    let content: String

    @Environment(\.presentationMode) private var presentation

    var body: some View {
        NavigationView {
            WebBox(url: url, payload: payload)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(side == .cn ? "中国微信 · 解封" : "国外微信 · 解封")
                .navigationBarItems(leading: Button("关闭") { presentation.wrappedValue.dismiss() })
        }
    }

    private var payload: String {
        let d: [String: String] = ["email": email, "subject": subject, "content": content]
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
        ucc.addUserScript(WKUserScript(source: Self.js(payload), injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        cfg.userContentController = ucc
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.3 Mobile/15E148 Safari/604.1"
        if let u = URL(string: url) { wv.load(URLRequest(url: u)) }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func js(_ json: String) -> String {
        """
        (function(){
          var D = \(json);
          function set(el,v){
            if(!el||v===undefined)return;
            var p = el.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;
            var d = Object.getOwnPropertyDescriptor(p,'value');
            try{d.set.call(el,v);}catch(e){el.value=v;}
            ['input','change','keyup','blur'].forEach(function(t){el.dispatchEvent(new Event(t,{bubbles:true}));});
          }
          function lbl(el){
            var s=[el.name,el.id,el.placeholder,el.getAttribute('aria-label')].filter(Boolean).join(' ');
            var l=el.closest('label'); if(l) s+=' '+l.textContent;
            var w=el.closest('div,li,tr,section,form'); if(w&&w.textContent) s+=' '+w.textContent.slice(0,200);
            return s.toLowerCase();
          }
          function fill(){
            var ins=[].slice.call(document.querySelectorAll('input,textarea'))
              .filter(function(e){return e.offsetParent!==null&&e.type!=='hidden'&&!e.value;});
            ins.forEach(function(el){
              var k=lbl(el);
              if(/e-?mail/.test(k)) set(el,D.email);
              else if(/subject|主题|标题/.test(k)) set(el,D.subject);
              else if(el.tagName==='TEXTAREA'&&/descript|detail|content|message|问题|描述|说明|申诉/.test(k)) set(el,D.content);
            });
            var ta=[].slice.call(document.querySelectorAll('textarea'))
              .filter(function(e){return e.offsetParent!==null;})
              .sort(function(a,b){return (b.rows*b.cols)-(a.rows*a.cols);})[0];
            if(ta&&!ta.value) set(ta,D.content);
            var bar=document.createElement('div');
            bar.textContent='已自动填好，核对后点提交';
            bar.style.cssText='position:fixed;left:12px;right:12px;bottom:18px;z-index:99999;background:#12b359;color:#fff;padding:12px;border-radius:12px;font:15px -apple-system;text-align:center';
            document.body.appendChild(bar);
            setTimeout(function(){bar.remove();},5000);
          }
          setTimeout(fill,1200);
          setTimeout(fill,3200);
        })();
        """
    }
}
