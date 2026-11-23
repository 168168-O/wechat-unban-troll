import SwiftUI

struct CleanView: View {
    @ObservedObject private var log = LogStore.shared
    @State private var opts = CleanOptions()
    @State private var running = false
    @State private var lastBackup = ""
    @State private var wx = EnvCheck.WeChatInfo()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("微信"), footer: Text("手机上的微信先退出登录，不用删 App")) {
                    Text(wx.installed ? "已装 \(wx.version)" : "未检测到微信")
                    Text(wx.dataPath).font(.system(size: 10, design: .monospaced))
                    Button("重新扫描") {
                        wx = EnvCheck.wechat()
                        log.log("重新扫描: 容器=\(wx.dataPath)")
                    }
                }

                Section(header: Text("清理项")) {
                    Toggle("偏好 Library/Preferences", isOn: $opts.prefs)
                    Toggle("缓存 Library/Caches + tmp + WebKit", isOn: $opts.caches)
                    Toggle("WechatPrivate 指纹库 + MMKV + Log", isOn: $opts.wechatPrivate)
                    Toggle("AppGroup 缓存与偏好", isOn: $opts.group)
                    Toggle("Documents 聊天库（本地记录会清掉）", isOn: $opts.chatDB)
                    Toggle("整个容器清空", isOn: $opts.wholeContainer)
                    Toggle("先备份再删", isOn: $opts.backup)
                }

                Section {
                    Button(running ? "执行中…" : "执行清理") { run() }
                        .disabled(running)
                    if !lastBackup.isEmpty {
                        Text("备份在 \(lastBackup)").font(.system(size: 10, design: .monospaced))
                    }
                }

                Section(header: Text("日志")) {
                    ScrollView {
                        Text(log.text).font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                }
            }
            .navigationTitle("清指纹")
            .onAppear { wx = EnvCheck.wechat() }
        }
    }

    private func run() {
        let L = LogStore.shared
        let info = EnvCheck.wechat()
        wx = info
        running = true
        L.log("=== 清指纹开始，容器=\(info.dataPath) ===")
        Cleaner.execute(info: info, opts: opts, log: { L.log($0) }) { dir in
            DispatchQueue.main.async {
                running = false
                lastBackup = dir ?? "未备份"
                L.log("=== 清指纹结束，备份=\(dir ?? "无") ===")
            }
        }
    }
}
