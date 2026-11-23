import SwiftUI
import UIKit

struct AppealView: View {
    @State private var input = AppealInput()
    @State private var tab = 0
    @State private var output = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("账号信息")) {
                    TextField("微信号 / wxid", text: $input.wxid)
                        .disableAutocorrection(true)
                    TextField("昵称", text: $input.nickname)
                    HStack {
                        TextField("区号", text: $input.cc)
                            .frame(width: 66)
                            .keyboardType(.phonePad)
                        TextField("手机号（不加 0）", text: $input.phone)
                            .keyboardType(.phonePad)
                    }
                    TextField("常驻国家", text: $input.region)
                    TextField("常驻城市", text: $input.city)
                    TextField("封禁提示原文", text: $input.reason)
                    TextField("被封日期", text: $input.date)
                    TextField("常用设备", text: $input.device)
                    TextField("iOS 版本", text: $input.ios)
                }

                Section {
                    Picker("输出类型", selection: $tab) {
                        Text("中文申诉").tag(0)
                        Text("English").tag(1)
                        Text("好友辅助").tag(2)
                        Text("解封步骤").tag(3)
                        Text("自查清单").tag(4)
                        Text("无好友辅助").tag(5)
                    }
                    Button("生成") { gen() }
                }

                Section(header: Text("结果")) {
                    ScrollView {
                        Text(output.isEmpty ? "填完上面点生成" : output)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 280)
                    HStack {
                        Button("复制") { UIPasteboard.general.string = output }
                        Button("分享") { share([output]) }
                    }
                }
            }
            .navigationTitle("申诉")
        }
    }

    private func gen() {
        switch tab {
        case 1: output = Appeal.english(input)
        case 2: output = Appeal.friendScript(input)
        case 3: output = Appeal.smsFlow(input)
        case 4: output = Appeal.checklist()
        case 5: output = Appeal.noFriend(input)
        default: output = Appeal.chinese(input)
        }
        LogStore.shared.log("生成申诉文案 type=\(tab) 长度=\(output.count)")
    }

    private func share(_ items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let win = scene.windows.first(where: { $0.isKeyWindow }),
              let root = win.rootViewController else { return }
        var top = root
        while let p = top.presentedViewController { top = p }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        top.present(vc, animated: true, completion: nil)
    }
}
