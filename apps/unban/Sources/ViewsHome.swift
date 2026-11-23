import SwiftUI

struct HomeView: View {
    @ObservedObject private var log = LogStore.shared
    @State private var wx = EnvCheck.WeChatInfo()
    @State private var ip: IPInfo?
    @State private var busy = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("当前状态")) {
                    kv("系统区域", EnvCheck.localeSummary())
                    kv("微信版本", wx.installed ? "\(wx.version)" : "未检测到")
                    kv("数据容器", wx.dataPath.isEmpty ? "-" : wx.dataPath)
                    kv("容器体积", wx.dataSize > 0
                       ? ByteCountFormatter.string(fromByteCount: wx.dataSize, countStyle: .file) : "-")
                    kv("AppGroup", wx.groupPath.isEmpty ? "-" : wx.groupPath)
                    kv("出口 IP", ip?.summary ?? "未测")
                }

                Section(header: Text("一键跑完")) {
                    Button(action: oneKey) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                            Text(busy ? "执行中…" : "清指纹 → 改区域 → 测 IP → 开安全中心")
                                .font(.system(size: 14))
                        }
                    }
                    .disabled(busy)
                }

                Section(header: Text("关键路径")) {
                    Text(Spoofer.globalPrefs)
                        .font(.system(size: 10, design: .monospaced))
                    Text("/var/mobile/Documents/WeChatUnbanBackup")
                        .font(.system(size: 10, design: .monospaced))
                }

                Section(header: HStack {
                    Text("日志")
                    Spacer()
                    Button("导出") { _ = log.export() }.font(.caption)
                    Button("清空") { log.clear() }.font(.caption)
                }) {
                    ScrollView {
                        Text(log.text.isEmpty ? "暂无日志" : log.text)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 220)
                }
            }
            .navigationTitle("跨境解封助手")
            .navigationBarItems(trailing: Button("刷新") { refresh() })
        }
        .onAppear(perform: refresh)
    }

    private func kv(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption).foregroundColor(.secondary)
            Text(v).font(.system(size: 12))
        }
    }

    private func refresh() {
        wx = EnvCheck.wechat()
        log.log("扫描微信: 安装=\(wx.installed) 版本=\(wx.version) 容器=\(wx.dataPath.isEmpty ? "无" : "有")")
        checkIP()
    }

    private func checkIP() {
        EnvCheck.ipInfo(proxy: SettingsStore.shared.proxy) { info in
            ip = info
            log.log("出口 IP: \(info?.summary ?? "探测失败")")
        }
    }

    private func oneKey() {
        let L = LogStore.shared
        let info = EnvCheck.wechat()
        wx = info
        busy = true
        L.log("=== 一键流程开始 ===")
        var opts = CleanOptions()
        opts.backup = true
        opts.chatDB = false
        Cleaner.execute(info: info, opts: opts, log: { L.log($0) }) { _ in
            let region = SettingsStore.shared.lastRegion
            _ = Spoofer.apply(region: region, setLanguage: true, log: { L.log($0) })
            EnvCheck.ipInfo(proxy: SettingsStore.shared.proxy) { i in
                DispatchQueue.main.async {
                    self.ip = i
                    L.log("出口 IP: \(i?.summary ?? "探测失败")")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                Bridge.openURL("https://weixin110.qq.com/")
                self.busy = false
                L.log("=== 一键流程收尾，去安全中心提交申诉 ===")
            }
        }
    }
}
