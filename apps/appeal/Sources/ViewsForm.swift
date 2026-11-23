import SwiftUI
import UIKit

struct FormView: View {
    @EnvironmentObject private var store: FormStore

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("收件邮箱（海外表单必填）"), footer: Text("海外通道只回邮件，写错就收不到结果")) {
                    TextField("your.email@example.com", text: $store.form.email)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }

                Section(header: Text("账号")) {
                    TextField("WeChat ID / wxid", text: $store.form.wxid)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    TextField("昵称 nickname", text: $store.form.nickname)
                    HStack {
                        TextField("+65", text: $store.form.cc)
                            .frame(width: 66)
                            .keyboardType(.phonePad)
                        TextField("手机号（不加 0）", text: $store.form.phone)
                            .keyboardType(.phonePad)
                    }
                    TextField("注册年月 reg date", text: $store.form.regDate)
                }

                Section(header: Text("地区")) {
                    TextField("Country", text: $store.form.country)
                    TextField("City", text: $store.form.city)
                    TextField("Issue date 12 Nov 2026", text: $store.form.issueDate)
                }

                Section(header: Text("设备")) {
                    TextField("iPhone 13", text: $store.form.device)
                    TextField("iOS 17.6", text: $store.form.ios)
                }

                Section(header: Text("封禁提示原文")) {
                    TextField("截图上那句话，一字不改", text: $store.form.banMessage)
                        .frame(minHeight: 60)
                }

                Section {
                    Button("清空全部字段") { store.form = AppealForm() }
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("表单")
        }
    }
}

struct TemplateView: View {
    @EnvironmentObject private var store: FormStore
    @State private var picked = "login"
    @State private var output = ""
    @State private var mode = 0

    private var item: TemplateItem { Templates.find(picked) }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("选模板")) {
                    Picker("模板", selection: $picked) {
                        ForEach(Templates.all) { t in
                            Text(t.title).tag(t.id)
                        }
                    }
                    Picker("输出", selection: $mode) {
                        Text("邮件正文").tag(0)
                        Text("表单填写块").tag(1)
                        Text("主题行").tag(2)
                    }
                    Button("生成") { gen() }
                }

                Section(header: Text("纯模板")) {
                    ScrollView {
                        Text(output.isEmpty ? "点生成" : output)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 320)
                    HStack {
                        Button("复制") { UIPasteboard.general.string = output }
                        Button("存到文件") { save() }
                        Button("分享") { share([output]) }
                    }
                }

                Section(header: Text("说明")) {
                    Text("模板里的 {{...}} 会被表单页填的内容替换，没填的留方括号占位，自己补。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("模板")
        }
    }

    private func gen() {
        switch mode {
        case 1: output = Templates.formBlock(store.form, item)
        case 2: output = store.form.fill(item.subject)
        default: output = store.form.fill(item.body)
        }
    }

    private func save() {
        let dir = "/var/mobile/Documents"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let name = "appeal-\(item.id)-\(Int(Date().timeIntervalSince1970)).txt"
        let path = dir + "/" + name
        try? output.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func share(_ items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let win = scene.windows.first(where: { $0.isKeyWindow }),
              let root = win.rootViewController else { return }
        var top = root
        while let p = top.presentedViewController { top = p }
        top.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }
}
