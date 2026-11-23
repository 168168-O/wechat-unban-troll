import SwiftUI

struct EnvView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var log = LogStore.shared
    @State private var ip: IPInfo?
    @State private var checking = false
    @State private var setLang = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("出口 IP 检测"), footer: Text("SOCKS5 填局域网里跑代理的那台机器的地址，端口默认 1080")) {
                    Toggle("走 SOCKS5", isOn: $settings.proxy.enabled)
                    TextField("代理地址 192.168.1.9", text: $settings.proxy.host)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                    TextField("端口", value: $settings.proxy.port, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                    Button(checking ? "检测中…" : "开始检测") { check() }
                        .disabled(checking)
                    if let i = ip {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(i.summary).font(.footnote)
                            Text("国别 \(i.countryCode)  机房 \(i.hosting ? "是" : "否")  标记代理 \(i.proxyFlag ? "是" : "否")  时区 \(i.timezone)")
                                .font(.caption)
                                .foregroundColor(i.hosting ? .orange : .green)
                        }
                    }
                }

                Section(header: Text("系统区域伪装")) {
                    Picker("目标区域", selection: $settings.lastRegion) {
                        ForEach(Spoofer.presets) { p in
                            Text("\(p.name)  \(p.id)").tag(p.id)
                        }
                    }
                    Toggle("同时改系统语言", isOn: $setLang)
                    Button("写入并 respring") {
                        _ = Spoofer.apply(region: settings.lastRegion, setLanguage: setLang, log: { log.log($0) })
                    }
                    Button("还原原始区域") {
                        Spoofer.restore(log: { log.log($0) })
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("当前值")) {
                    Text(EnvCheck.localeSummary()).font(.system(size: 12, design: .monospaced))
                    Text("AppleLocale 写在 \(Spoofer.globalPrefs)")
                        .font(.system(size: 10, design: .monospaced))
                }

                Section(header: Text("日志")) {
                    ScrollView {
                        Text(log.text).font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                }
            }
            .navigationTitle("环境")
        }
    }

    private func check() {
        checking = true
        EnvCheck.ipInfo(proxy: settings.proxy) { info in
            checking = false
            ip = info
            if let i = info {
                log.log("IP \(i.query) \(i.country)/\(i.regionName)/\(i.city) hosting=\(i.hosting)")
            } else {
                log.log("IP 探测失败：代理没通或被墙")
            }
        }
    }
}
