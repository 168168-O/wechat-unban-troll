import SwiftUI
import WebKit

// 巨魔版：自带浏览器的申诉壳子，页面里直接注入填充+提交脚本
// 用法：打开 App 就是 help.wechat.com，底部两个按钮「填入并提交」「只填正文」

struct AutoFillView: View {
    @State private var status = "等待页面加载…"
    @State private var webView: WKWebView?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(status).font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Button("重载") { webView?.reload() }.font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            WebShell(status: $status, holder: $webView)

            HStack(spacing: 8) {
                Button {
                    webView?.evaluateJavaScript("window.__enappealFill(true)", completionHandler: nil)
                    status = "已触发：填入并提交"
                } label: {
                    Text("填入并提交").font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.green).foregroundColor(.black).cornerRadius(10)
                }
                Button {
                    webView?.evaluateJavaScript("window.__enappealFill(false)", completionHandler: nil)
                    status = "已触发：只填不提交"
                } label: {
                    Text("只填正文").font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct WebShell: UIViewRepresentable {
    @Binding var status: String
    @Binding var holder: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let ucc = WKUserContentController()

        // 资料填在这里
        let data = """
        {
          email: "your.email@example.com",
          wechatName: "fcfcmv520",
          wechatId: "fcfcmv520",
          cc: "+95",
          phone: "9XXXXXXXX",
          country: "Myanmar",
          city: "Wa State",
          registeredRegion: "Chinese Taiwan",
          regularLogin: "Wa State, Myanmar",
          regDate: "2026-04-26",
          lastLogin: "2026-10-30",
          device: "iPhone 12",
          ios: "17.6",
          banMessage: "Your account is restricted. Verify with a friend to unblock."
        }
        """

        let js = Self.injectJS(dataJSON: data)
        ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        cfg.userContentController = ucc
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: URL(string: "https://help.wechat.com/")!))

        DispatchQueue.main.async { holder = wv }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coord { Coord(status: $status) }

    final class Coord: NSObject, WKNavigationDelegate {
        @Binding var status: String
        init(status: Binding<String>) { _status = status }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            status = "已加载：\(webView.url?.absoluteString ?? "")"
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status = "加载失败：\(error.localizedDescription)"
        }
    }

    static func injectJS(dataJSON: String) -> String {
        """
        (function(){
          if (window.__enappealReady) { return; }
          window.__enappealReady = true;
          var DATA = \(dataJSON);

          var BODY_EN = "Dear WeChat Support Team,\\n\\n" +
            "I am writing to appeal the login restriction on my WeChat account. The account is locked by the cross-region login check, and the self-unblock flow stops at friend verification, which I have no way to complete. I am asking for manual verification of ownership and for the restriction to be lifted.\\n\\n" +
            "1. ACCOUNT INFORMATION\\n" +
            "- WeChat name: " + DATA.wechatName + "\\n" +
            "- WeChat ID: " + DATA.wechatId + "\\n" +
            "- Registration date: " + DATA.regDate + "\\n" +
            "- Last normal login: " + DATA.lastLogin + "\\n" +
            "- Linked mobile number: " + DATA.cc + " " + DATA.phone + "\\n" +
            "- Device in use: " + DATA.device + ", iOS " + DATA.ios + "\\n" +
            "- Registered region: " + DATA.registeredRegion + "\\n" +
            "- Regular login location: " + DATA.regularLogin + "\\n\\n" +
            "2. TIMELINE\\n" +
            "1. " + DATA.regDate + ": the account was registered and has been used on " + DATA.device + " ever since.\\n" +
            "2. " + DATA.lastLogin + ": last normal login, from " + DATA.regularLogin + ", on my own mobile data and home Wi-Fi.\\n" +
            "3. After that: login blocked, with the message \\"" + DATA.banMessage + "\\".\\n\\n" +
            "3. WHY THE SYSTEM FLAGGED ME, AND WHY IT IS A FALSE POSITIVE\\n" +
            "My registered region is " + DATA.registeredRegion + " because I registered the account while travelling there. I live in " + DATA.regularLogin + " and I use my own local number " + DATA.cc + " " + DATA.phone + ". The registered region, the country of the number and my login location differ, which is the pattern the system reads as abnormal. For me it is normal: one person, one device, one city, for months.\\n\\n" +
            "4. MY USE OF THE ACCOUNT\\n" +
            "1. This is a personal account. I use it for family chats, one work group and payments.\\n" +
            "2. I have sent no advertising, no mass messages, no forward chains and no investment offers.\\n" +
            "3. I have asked nobody for money, passwords, verification codes or bank details, and I have never traded or rented the account.\\n" +
            "4. I have not used bulk-add tools, auto-reply bots, account farms, virtual numbers or any modified WeChat client.\\n" +
            "5. I have received no complaint notice from WeChat before this restriction.\\n\\n" +
            "5. FRIEND VERIFICATION\\n" +
            "The self-unblock page shows: \\"" + DATA.banMessage + "\\" It asks for a WeChat friend to confirm, and there is no friend available on my side to do it, so this step stops here. A screenshot of that page is attached as item 01.\\n\\n" +
            "6. WHAT I AM ASKING FOR\\n" +
            "1. Please verify ownership of this account manually, using the number " + DATA.cc + " " + DATA.phone + ", the device " + DATA.device + " and the documents attached.\\n" +
            "2. Please lift the login restriction on " + DATA.wechatId + " and let me sign in with an SMS code sent to " + DATA.cc + " " + DATA.phone + ".\\n" +
            "3. Please reply with the result to " + DATA.email + ".\\n\\n" +
            "7. EVIDENCE ATTACHED\\n" +
            "01 - Screenshot of the self-unblock page asking for friend verification\\n" +
            "02 - Phone bill in my name showing " + DATA.cc + " " + DATA.phone + "\\n" +
            "03 - Screenshot of Settings > General > About\\n" +
            "04 - WeChat > Settings > Account Security > Devices\\n" +
            "05 - Proof of residence in " + DATA.regularLogin + "\\n" +
            "06 - Screenshot of my last normal chat activity before the lock\\n\\n" +
            "I have used this account daily for personal communication, I have broken no rule, and I am asking only to get back into my own account.\\n\\n" +
            "Sincerely,\\n" + DATA.wechatName + "\\nWeChat ID " + DATA.wechatId + "\\nLinked number " + DATA.cc + " " + DATA.phone + "\\nContact email " + DATA.email;

          function setVal(el, v){
            var proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
            var d = Object.getOwnPropertyDescriptor(proto, "value");
            try { d.set.call(el, v); } catch(e) { el.value = v; }
            ["input","change","keyup","blur"].forEach(function(t){ el.dispatchEvent(new Event(t,{bubbles:true})); });
          }

          function labelOf(el){
            var s = [el.name, el.id, el.placeholder, el.getAttribute("aria-label"), el.className].filter(Boolean).join(" ");
            var lab = el.closest("label");
            if (lab) s += " " + lab.textContent;
            var w = el.closest("div,li,tr,section,form");
            if (w && w.textContent && w.textContent.length < 300) s += " " + w.textContent;
            return s.toLowerCase();
          }

          function fill(submit){
            var done = 0;
            var put = function(re, v){
              var list = Array.prototype.slice.call(document.querySelectorAll("input,textarea"))
                .filter(function(el){ return el.offsetParent !== null && el.type !== "hidden"; });
              for (var i = 0; i < list.length; i++){
                if (re.test(labelOf(list[i])) && !(list[i].value && list[i].value.trim().length)) {
                  setVal(list[i], v); done++; return;
                }
              }
            };
            put(/e-?mail/, DATA.email);
            put(/wechat\\s*id|wxid|account id/, DATA.wechatId);
            put(/nick\\s*name|display name|name on account/, DATA.wechatName);
            put(/phone|mobile|number/, DATA.cc + " " + DATA.phone);
            put(/country|region/, DATA.country);
            put(/city/, DATA.city);

            var areas = Array.prototype.slice.call(document.querySelectorAll("textarea"))
              .filter(function(e){ return e.offsetParent !== null; })
              .sort(function(a,b){ return (b.rows*b.cols) - (a.rows*a.cols); });
            if (areas[0]) { setVal(areas[0], BODY_EN); done++; }

            if (submit) {
              setTimeout(function(){
                var words = /submit|send|appeal|confirm|next|continue/i;
                var btns = Array.prototype.slice.call(document.querySelectorAll("button,input[type=submit],a"))
                  .filter(function(b){ return b.offsetParent !== null && words.test((b.textContent||b.value||"")); });
                if (btns[0]) { btns[0].scrollIntoView({block:"center"}); btns[0].click(); }
              }, 1500);
            }
            return done;
          }

          window.__enappealFill = function(submit){ return fill(!!submit); };

          var box = document.createElement("div");
          box.style.cssText = "position:fixed;right:12px;bottom:120px;z-index:999999;display:flex;flex-direction:column;gap:8px";
          var b1 = document.createElement("button");
          b1.textContent = "填入并提交";
          b1.style.cssText = "padding:12px 16px;border:none;border-radius:22px;background:#3ddc84;color:#07130c;font-weight:700;font-size:14px";
          b1.onclick = function(){ fill(true); };
          var b2 = document.createElement("button");
          b2.textContent = "只填正文";
          b2.style.cssText = "padding:12px 16px;border:none;border-radius:22px;background:#1f6feb;color:#fff;font-weight:700;font-size:14px";
          b2.onclick = function(){ fill(false); };
          box.appendChild(b1); box.appendChild(b2);
          setTimeout(function(){ document.body.appendChild(box); }, 1200);
        })();
        """
    }
}
