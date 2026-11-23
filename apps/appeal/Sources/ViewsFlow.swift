import SwiftUI

struct FlowStep: Identifiable {
    let id: Int
    let title: String
    let text: String
}

struct FlowView: View {
    @EnvironmentObject private var store: FormStore

    private var steps: [FlowStep] {
        let mail = store.form.email.isEmpty ? "[先回表单页填邮箱]" : store.form.email
        let wxid = store.form.wxid.isEmpty ? "[WeChat ID]" : store.form.wxid
        let phone = store.form.phone.isEmpty ? "[number]" : store.form.phone
        return [
            FlowStep(id: 1,
                     title: "1. 走海外站，别碰国内站",
                     text: "国内 weixin110.qq.com 的解封表单挂在国内手机号体系上，海外号填进去直接判死。海外通道是 help.wechat.com 与 www.wechat.com/en，同一套工单系统，全程英文，回复走邮件。"),
            FlowStep(id: 2,
                     title: "2. 入口路径",
                     text: "help.wechat.com → Account & Security → Sign-in Issues → Account restricted / Appeal → 表单。官网 www.wechat.com/en 底部 Help & Support 落到同一张表。"),
            FlowStep(id: 3,
                     title: "3. 表单必填项",
                     text: "Email address：\(mail)（只回这里，垃圾箱一起盯）\nWeChat ID：\(wxid)\nRegistered number：\(store.form.cc) \(phone)\nCountry / Region：\(store.form.country) / \(store.form.city)\nDescription：贴「模板」页生成的英文正文。"),
            FlowStep(id: 4,
                     title: "4. 附件四件套",
                     text: "① 封禁提示截图，原文别裁 ② 号码话费账单，带姓名与号码 ③ 设置-通用-关于本机，机型与 iOS 版本 ④ 微信-设置-账号与安全-登录设备管理。PNG 与 PDF 都收，单张压在 5MB 以内。"),
            FlowStep(id: 5,
                     title: "5. 主题行固定格式",
                     text: "Appeal: login restriction on WeChat ID \(wxid) — registered number \(store.form.cc) \(phone)。正文纯文本，不带花体、不加粗、不放 emoji，对方分单靠这行。"),
            FlowStep(id: 6,
                     title: "6. 提交节奏",
                     text: "提交后 72 小时看回信；没回就在同一工单下追一封，只写工单号加一句 Please advise on the status of this appeal。驳回停 15 天再提，同一账号累计不超过 3 次。"),
            FlowStep(id: 7,
                     title: "7. 回信后怎么接",
                     text: "对方列材料当天回，附件按他们编号改名：01-id.png、02-bill.pdf、03-device.png、04-login-history.png。给了验证链接 24 小时内点完，超时链接作废重排。"),
            FlowStep(id: 8,
                     title: "8. 三条硬规矩",
                     text: "一封邮件只讲一个账号；别用免费临时邮箱，域名直接进低优先队列；同一时间只走海外通道一个入口，两边同时提会让工单互锁。")
        ]
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("海外申诉流程（邮件制）")) {
                    ForEach(steps) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.title).font(.system(size: 13, weight: .semibold))
                            Text(s.text).font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                Section(header: Text("模板速查")) {
                    ForEach(Templates.all) { t in
                        Text(t.title).font(.system(size: 12))
                    }
                }
            }
            .navigationTitle("流程")
        }
    }
}
