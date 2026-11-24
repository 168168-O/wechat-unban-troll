import SwiftUI
import WebKit
import AVFoundation
import PhotosUI

// 牛头解封 · 视觉沿用 BullTroll：黑底、红金渐变、材质卡片、logo 主视觉
// 功能沿用三屏：选通道 → 填三格 → 一键生成并自动填入官网

enum Side: String {
    case cn, intl
    var title: String { self == .cn ? "中国微信" : "国外微信" }
    var hint: String { self == .cn ? "+86 手机号注册" : "+65 / +95 这类" }
    var symbol: String { self == .cn ? "message.fill" : "globe" }
    var url: String {
        self == .cn
            ? "https://weixin110.qq.com/cgi-bin/mmspamsupport-bin/newredirectconfirmcgi?main_type=appeal"
            : "https://help.wechat.com/cgi-bin/newreadtemplate?t=help_center/feedback_form&lang=en&Channel=WeChatOfficialWebsite"
    }
}

private enum Palette {
    static let accent = Color(red: 0.93, green: 0.22, blue: 0.18)
    static let accentDeep = Color(red: 0.55, green: 0.09, blue: 0.08)
    static let base = Color.black
    static let display = "AvenirNext-DemiBold"
}

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    func say(_ t: String) {
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        u.rate = 0.45
        synth.speak(u)
    }
}

final class Model: ObservableObject {
    @Published var side: Side? = nil
    @Published var wxid = ""
    @Published var phone = ""
    @Published var cc = "+95"
    @Published var email = ""
    @Published var step = 0
    @Published var shot: UIImage? = nil

    init() {
        let d = UserDefaults.standard
        wxid = d.string(forKey: "u.wxid") ?? ""
        phone = d.string(forKey: "u.phone") ?? ""
        cc = d.string(forKey: "u.cc") ?? "+95"
        email = d.string(forKey: "u.email") ?? ""
        if let s = d.string(forKey: "u.side"), let v = Side(rawValue: s) { side = v }
    }

    func save() {
        let d = UserDefaults.standard
        d.set(wxid, forKey: "u.wxid")
        d.set(phone, forKey: "u.phone")
        d.set(cc, forKey: "u.cc")
        d.set(email, forKey: "u.email")
        d.set(side?.rawValue ?? "", forKey: "u.side")
    }

    var ready: Bool { !wxid.isEmpty && !phone.isEmpty && !email.isEmpty }
}

@main
struct UnbanApp: App {
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    @StateObject private var m = Model()
    @State private var showWeb = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                Group {
                    if m.step == 0 { channelStep } else if m.step == 1 { formStep } else { applyStep }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
        }
        .sheet(isPresented: $showWeb) {
            WebFill(side: m.side ?? .intl, url: (m.side ?? .intl).url,
                    email: m.email, subject: subject(), content: contentText())
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            Speaker.shared.say(speech())
        }
    }

    // MARK: 背景

    private var background: some View {
        ZStack {
            Palette.base.ignoresSafeArea()
            RadialGradient(colors: [Palette.accent.opacity(0.30), Palette.accent.opacity(0.05), .clear],
                           center: .init(x: 0.5, y: 0.14), startRadius: 8, endRadius: 330)
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, Color.black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    // MARK: 顶栏

    private var topBar: some View {
        HStack(spacing: 12) {
            if let logo = UIImage(named: "logo") {
                Image(uiImage: logo).resizable().scaledToFit().frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("牛头解封").font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.7)],
                                                    startPoint: .top, endPoint: .bottom))
                Text("UNBAN · \(m.step + 1)/3")
                    .font(.custom(Palette.display, size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            Spacer()
            Button { Speaker.shared.say(speech()) } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: 底部

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if m.step > 0 {
                Button {
                    m.step -= 1
                    Speaker.shared.say(speech())
                } label: {
                    Text("上一步").font(.custom(Palette.display, size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
            Button { advance() } label: {
                HStack(spacing: 8) {
                    Image(systemName: m.step == 2 ? "paperplane.fill" : "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                    Text(m.step == 2 ? "生成并申请" : "下一步")
                        .font(.custom(Palette.display, size: 16))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.accent, Palette.accentDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(LinearGradient(colors: [Color.white.opacity(0.22), .clear],
                                                startPoint: .top, endPoint: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)))
                )
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: Palette.accent.opacity(0.42), radius: 22, x: 0, y: 10)
                .opacity(canAdvance ? 1 : 0.45)
            }
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var canAdvance: Bool {
        if m.step == 0 { return m.side != nil }
        if m.step == 1 { return m.ready }
        return true
    }

    private func advance() {
        if m.step < 2 {
            m.save()
            m.step += 1
            Speaker.shared.say(speech())
        } else {
            m.save()
            showWeb = true
        }
    }

    private func speech() -> String {
        switch m.step {
        case 0: return "第一步。你的微信是哪种手机号注册的。中国号点左边，国外号点右边。"
        case 1: return "第二步。填微信号、手机号、收结果的邮箱。"
        default: return "第三步。点生成并申请，我会打开官方网站，把内容自动填好。"
        }
    }

    // MARK: 第 1 屏

    private var channelStep: some View {
        VStack(spacing: 16) {
            Text("你的微信，是用哪种手机号注册的？")
                .font(.system(size: 19, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.86))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            sideCard(.cn)
            sideCard(.intl)
            Spacer()
        }
    }

    private func sideCard(_ s: Side) -> some View {
        Button {
            m.side = s
            m.step = 1
            Speaker.shared.say(s == .cn ? "你选了国内。" : "你选了国外。")
        } label: {
            HStack(spacing: 16) {
                Image(systemName: s.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 58, height: 58)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(s.title).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    Text(s.hint).font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(m.side == s ? 0.10 : 0.035)))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(m.side == s ? 0.30 : 0.12), lineWidth: 1))
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: 第 2 屏

    private var formStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                field("微信号", "wxid 开头那串也行", $m.wxid, .default)
                field("手机号", "只填数字，去掉开头的 0", $m.phone, .phonePad)
                field("收结果的邮箱", "没有就填家人的", $m.email, .emailAddress)
                photoRow
                if let img = m.shot {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(height: 120).cornerRadius(12).padding(.horizontal, 20)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showPicker) { ImagePicker(image: $m.shot) }
    }

    @State private var showPicker = false

    private var photoRow: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.accent)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(m.shot == nil ? "选一张封禁截图（可不选）" : "已选截图，点这里换")
                    .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.75))
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func field(_ title: String, _ hint: String, _ text: Binding<String>, _ kb: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.custom(Palette.display, size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
            TextField(hint, text: text)
                .font(.system(size: 18))
                .keyboardType(kb)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, 20)
    }

    // MARK: 第 3 屏

    private var applyStep: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 12) {
                row("通道", (m.side ?? .intl).title)
                divider
                row("微信号", m.wxid)
                divider
                row("手机号", m.cc + " " + m.phone)
                divider
                row("邮箱", m.email)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 20)

            Text("进去以后核对一下，点页面上的提交")
                .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.4))
            Spacer()
        }
    }

    private var divider: some View { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.45))
            Spacer()
            Text(v.isEmpty ? "未填" : v).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: 文案

    private func subject() -> String {
        m.side == .cn
            ? "申诉：账号 \(m.wxid) 登录受限，申请人工核验"
            : "Appeal: \(m.wxid) — login restriction, manual verification requested"
    }

    private func contentText() -> String {
        if m.side == .cn {
            return """
            微信安全中心：

            我的微信账号 \(m.wxid)，绑定手机 \(m.cc) \(m.phone)，现被限制登录。自助解封要求好友辅助验证，我这边没有可配合的好友，走不下去，申请人工核验。

            一、账号情况
            1. 账号一直由本人使用，没有外借、出租或买卖。
            2. 绑定手机 \(m.cc) \(m.phone) 在本人手上，可随时接收验证码。
            3. 没有群发、没有加粉、没有使用外挂或改版客户端。

            二、申请事项
            1. 请人工核验账号归属，解除 \(m.wxid) 的登录限制。
            2. 验证码可发送至 \(m.cc) \(m.phone)。
            3. 处理结果请回信至 \(m.email)。

            联系电话：\(m.cc) \(m.phone)
            """
        }
        return """
        Dear WeChat Support Team,

        I am writing to appeal the login restriction on my WeChat account.

        - WeChat ID: \(m.wxid)
        - Linked mobile number: \(m.cc) \(m.phone)
        - Contact email: \(m.email)
        - Device: iPhone 12

        The account is locked by the cross-region login check, and the self-unblock flow stops at friend verification, which I have no way to complete. I am asking for manual verification of ownership and for the restriction to be lifted.

        1. This is a personal account used by me only. It has never been sold, rented or shared.
        2. I have sent no advertising, no mass messages and no investment offers.
        3. I have not used bulk-add tools, bots, account farms, virtual numbers or modified clients.
        4. The number \(m.cc) \(m.phone) is in my hands and receives SMS at any time.

        Please verify ownership manually and lift the restriction on \(m.wxid). Please reply to \(m.email).

        Sincerely,
        WeChat ID \(m.wxid)
        """
    }
}

// MARK: - 选图

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
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, PHPickerViewControllerDelegate {
        private let p: ImagePicker
        init(_ p: ImagePicker) { self.p = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
            item.loadObject(ofClass: UIImage.self) { img, _ in
                DispatchQueue.main.async { self.p.image = img as? UIImage }
            }
        }
    }
}

// MARK: - 自动填入

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
                .navigationTitle(side == .cn ? "中国微信 · 解封" : "国外微信 · 解封")
                .navigationBarTitleDisplayMode(.inline)
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

    func updateUIView(_ v: WKWebView, context: Context) {}

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
            bar.style.cssText='position:fixed;left:12px;right:12px;bottom:18px;z-index:99999;background:#ed3833;color:#fff;padding:12px;border-radius:12px;font:15px -apple-system;text-align:center';
            document.body.appendChild(bar);
            setTimeout(function(){bar.remove();},5000);
          }
          setTimeout(fill,1200);
          setTimeout(fill,3200);
        })();
        """
    }
}
