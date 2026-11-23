import Foundation
import SwiftUI
import Combine

struct AppealForm: Codable {
    var email = ""
    var wxid = ""
    var nickname = ""
    var cc = "+65"
    var phone = ""
    var country = "Singapore"
    var city = "Singapore"
    var issueDate = ""
    var device = "iPhone 13"
    var ios = "17.6"
    var regDate = ""
    var banMessage = ""

    func fill(_ s: String) -> String {
        var out = s
        let map: [String: String] = [
            "{{EMAIL}}": email.isEmpty ? "[your.email@example.com]" : email,
            "{{WECHAT_ID}}": wxid.isEmpty ? "[WeChat ID]" : wxid,
            "{{NICKNAME}}": nickname.isEmpty ? "[your name]" : nickname,
            "{{CC}}": cc.isEmpty ? "+65" : cc,
            "{{PHONE}}": phone.isEmpty ? "[phone number]" : phone,
            "{{COUNTRY}}": country.isEmpty ? "[country]" : country,
            "{{CITY}}": city.isEmpty ? "[city]" : city,
            "{{DATE}}": issueDate.isEmpty ? "[date, e.g. 12 Nov 2026]" : issueDate,
            "{{DEVICE}}": device.isEmpty ? "iPhone" : device,
            "{{IOS}}": ios.isEmpty ? "[iOS version]" : ios,
            "{{REG_DATE}}": regDate.isEmpty ? "[month and year the account was created]" : regDate,
            "{{BAN}}": banMessage.isEmpty ? "your account has been restricted" : banMessage
        ]
        for (k, v) in map {
            out = out.replacingOccurrences(of: k, with: v)
        }
        return out
    }
}

final class FormStore: ObservableObject {
    @Published var form = AppealForm() {
        didSet { save() }
    }

    private let key = "appeal.form.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let f = try? JSONDecoder().decode(AppealForm.self, from: raw) {
            form = f
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(form) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}

struct TemplateItem: Identifiable {
    let id: String
    let title: String
    let subject: String
    let body: String
}

enum Templates {
    static let all: [TemplateItem] = [loginRestriction, reportedContent, marketingFlag, stolenAccount, newDevice, paymentRestriction]

    static func find(_ id: String) -> TemplateItem {
        all.first { $0.id == id } ?? all[0]
    }

    static func formBlock(_ f: AppealForm, _ t: TemplateItem) -> String {
        """
        ────────────────────────────────
        FORM FIELDS — paste into help.wechat.com / wechat.com/en appeal form
        ────────────────────────────────
        Email address (required, replies come here):
        \(f.email.isEmpty ? "[your.email@example.com]" : f.email)

        WeChat ID:
        \(f.wxid.isEmpty ? "[WeChat ID]" : f.wxid)

        Nickname on account:
        \(f.nickname.isEmpty ? "[name]" : f.nickname)

        Registered mobile number:
        \(f.cc) \(f.phone.isEmpty ? "[number]" : f.phone)

        Country / Region:
        \(f.country) / \(f.city)

        Email subject:
        \(f.fill(t.subject))

        Description / Issue details:
        \(f.fill(t.body))

        Attachments (upload all four):
        1. Screenshot of the restriction message exactly as shown
        2. Phone bill under my name showing \(f.cc) \(f.phone)
        3. Settings > General > About (device model and iOS version)
        4. WeChat > Settings > Account Security > Devices
        """
    }

    // MARK: - 1

    static let loginRestriction = TemplateItem(
        id: "login",
        title: "1. 登录受限 / 环境异常（Login restricted）",
        subject: "Appeal: login restriction on WeChat ID {{WECHAT_ID}} — registered number {{CC}} {{PHONE}}",
        body: """
        Dear WeChat Support Team,

        I am writing to appeal the login restriction placed on my WeChat account.

        ACCOUNT DETAILS
        - WeChat ID: {{WECHAT_ID}}
        - Nickname: {{NICKNAME}}
        - Registered mobile number: {{CC}} {{PHONE}}
        - Country / region: {{COUNTRY}}, {{CITY}}
        - Contact email for your reply: {{EMAIL}}
        - Account created: {{REG_DATE}}
        - Device: {{DEVICE}}, iOS {{IOS}}

        WHAT HAPPENED
        On {{DATE}} I opened WeChat and received this message: "{{BAN}}". Since then the account has been blocked from logging in.

        WHY THIS RESTRICTION IS A MISTAKE
        1. I live and work in {{CITY}}, {{COUNTRY}}. The number on the account is my local number and it receives SMS normally.
        2. I use one device, {{DEVICE}} running iOS {{IOS}}, and I have used it for months. There has been no new device, no SIM swap and no shared login.
        3. I have never given my password or verification codes to anyone and I have never paid a third party to log in for me.
        4. I have not used bulk messaging, friend-farming, automation tools or modified WeChat clients.
        5. I have not posted prohibited content and I have received no complaint notice from WeChat.

        WHAT I AM ASKING FOR
        1. Please review the automated restriction on this account and restore normal login.
        2. Please send the verification code to {{CC}} {{PHONE}}, or reply to {{EMAIL}}.
        3. If documents are needed, I can provide a local phone bill in my name, my ID document, proof of residence in {{COUNTRY}} and device screenshots.

        ATTACHMENTS
        1. Screenshot of the restriction message
        2. Local phone bill showing {{CC}} {{PHONE}} in my name
        3. Screenshot of Settings > General > About
        4. Screenshot of WeChat > Settings > Account Security > Devices

        I can be reached at {{EMAIL}} or {{CC}} {{PHONE}}.

        Sincerely,
        {{NICKNAME}}
        WeChat ID {{WECHAT_ID}}
        """
    )

    // MARK: - 2

    static let reportedContent = TemplateItem(
        id: "reported",
        title: "2. 被他人举报 / 内容投诉（Reported）",
        subject: "Appeal: account {{WECHAT_ID}} restricted after a user report — request for review",
        body: """
        Dear WeChat Support Team,

        I am appealing the restriction on my account, which I understand was placed after reports from other users.

        ACCOUNT DETAILS
        - WeChat ID: {{WECHAT_ID}}
        - Registered mobile number: {{CC}} {{PHONE}}
        - Country / region: {{COUNTRY}}, {{CITY}}
        - Contact email: {{EMAIL}}

        WHAT HAPPENED
        On {{DATE}} my account was restricted with this message: "{{BAN}}". I received no prior warning and no details of the reported content.

        MY USE OF THE ACCOUNT
        1. This account is personal. It is used for family chats, work groups and payments. It is registered to my own number, {{CC}} {{PHONE}}.
        2. I have not sent unsolicited advertising, mass messages, forward chains or investment offers.
        3. I have not asked anyone for money, passwords, verification codes or bank details.
        4. I have not posted political, sexual, gambling or illegal content.
        5. My contact list is small and made up of people I know in person in {{CITY}}.

        REQUEST
        1. Please send me the specific message or conduct that triggered the report, with the date and the chat it came from.
        2. Please review that material against your Community Guidelines.
        3. If any single message was misread out of context, I am willing to delete it and to keep the account under review.

        I am ready to verify my identity with my ID document, local phone bill and residence proof. Please reply to {{EMAIL}}.

        Sincerely,
        {{NICKNAME}}
        WeChat ID {{WECHAT_ID}}
        Registered number {{CC}} {{PHONE}}
        """
    )

    // MARK: - 3

    static let marketingFlag = TemplateItem(
        id: "marketing",
        title: "3. 误判批量注册 / 营销（Marketing）",
        subject: "Appeal: false positive on WeChat ID {{WECHAT_ID}} — single personal account, no automation",
        body: """
        Dear WeChat Support Team,

        My account has been flagged for bulk registration or marketing activity. This is a false positive and I am asking for a manual review.

        ACCOUNT DETAILS
        - WeChat ID: {{WECHAT_ID}}
        - Registered mobile number: {{CC}} {{PHONE}}
        - Country / region: {{COUNTRY}}, {{CITY}}
        - Contact email: {{EMAIL}}
        - Account created: {{REG_DATE}}
        - Device: {{DEVICE}}, iOS {{IOS}}

        THE FACTS
        1. This is my only WeChat account. I hold one number, {{CC}} {{PHONE}}, and it is registered in my own name.
        2. I run no shop, no agency and no reseller business on WeChat. I have no second device and no second SIM.
        3. I have not used group-blasting tools, auto-reply bots, account farms, virtual numbers or any modified client.
        4. My message volume is normal for a personal account: family, one work group and a few friends in {{CITY}}.
        5. I have not added strangers in bulk and I have not sent the same message to many chats.

        WHAT TRIGGERED IT, AS FAR AS I CAN SEE
        On {{DATE}} I logged in from a new network after moving within {{COUNTRY}}. That login is mine. The message shown was: "{{BAN}}".

        REQUEST
        1. Please review the device and number history on this account: one device, {{DEVICE}}, one number, {{CC}} {{PHONE}}, since {{REG_DATE}}.
        2. Please lift the restriction and remove the marketing flag from the account.
        3. Please reply to {{EMAIL}} with the result.

        Sincerely,
        {{NICKNAME}}
        WeChat ID {{WECHAT_ID}}
        """
    )

    // MARK: - 4

    static let stolenAccount = TemplateItem(
        id: "stolen",
        title: "4. 账号被盗后被封（Taken over）",
        subject: "Urgent: account {{WECHAT_ID}} was taken over — appeal against resulting restriction",
        body: """
        Dear WeChat Support Team,

        My account was accessed by someone else and then restricted. I am asking for the restriction to be lifted and for the intruder's session to be removed.

        ACCOUNT DETAILS
        - WeChat ID: {{WECHAT_ID}}
        - Registered mobile number: {{CC}} {{PHONE}}
        - Country / region: {{COUNTRY}}, {{CITY}}
        - Contact email: {{EMAIL}}
        - Device I own: {{DEVICE}}, iOS {{IOS}}

        TIMELINE
        1. {{DATE}}: I received a login notification for a device and location that are not mine.
        2. Shortly after, my password stopped working and my account showed: "{{BAN}}".
        3. I still hold the registered number {{CC}} {{PHONE}} and I can receive SMS on it right now.

        EVIDENCE THAT I AM THE OWNER
        1. The registered number is in my name and the phone bill is attached.
        2. This account has been on {{DEVICE}} since {{REG_DATE}}.
        3. I know the account password history and the contacts I talk to most in {{CITY}}.
        4. My payment records on the account match my own bank card.

        WHAT I AM ASKING FOR
        1. Remove every active session except {{DEVICE}}.
        2. Restore login and let me set a new password through {{CC}} {{PHONE}}.
        3. Clear any restriction or flag added while the intruder held the account.
        4. Reply to {{EMAIL}} with the outcome.

        Sincerely,
        {{NICKNAME}}
        WeChat ID {{WECHAT_ID}}
        """
    )

    // MARK: - 5

    static let newDevice = TemplateItem(
        id: "device",
        title: "5. 换机换号后被拦（New phone）",
        subject: "Appeal: login blocked after device change — WeChat ID {{WECHAT_ID}}",
        body: """
        Dear WeChat Support Team,

        I replaced my phone and changed my local number. Since then WeChat blocks my login at the verification step and the automated flow keeps sending me back to the same page.

        ACCOUNT DETAILS
        - WeChat ID: {{WECHAT_ID}}
        - Registered mobile number: {{CC}} {{PHONE}}
        - Country / region: {{COUNTRY}}, {{CITY}}
        - Contact email: {{EMAIL}}
        - Old device: replaced on {{DATE}}
        - New device: {{DEVICE}}, iOS {{IOS}}

        DETAILS
        1. The old handset was sold. I moved my local SIM to the new handset and kept the same number, {{CC}} {{PHONE}}.
        2. The message I receive is: "{{BAN}}".
        3. The verification SMS arrives on {{CC}} {{PHONE}} and I enter it within seconds.
        4. I have no second account and no friend-verification partner available, so the automated flow stops here.

        REQUEST
        1. Please approve {{DEVICE}} as my trusted device for this account.
        2. Please send the login verification to {{CC}} {{PHONE}}, or reply to {{EMAIL}} with a manual verification step.
        3. I can provide the phone bill for {{CC}} {{PHONE}}, my ID document and a photo of the handset with the SIM tray open.

        Sincerely,
        {{NICKNAME}}
        WeChat ID {{WECHAT_ID}}
        """
    )

    // MARK: - 6

    static let paymentRestriction = TemplateItem(
        id: "payment",
        title: "6. 微信支付受限（WeChat Pay）",
        subject: "Appeal: WeChat Pay restriction on account {{WECHAT_ID}} — funds held",
        body: """
        Dear WeChat Support Team,

        My WeChat Pay wallet has been restricted and there is a balance I need access to. I am asking for a review.

        ACCOUNT DETAILS
        - WeChat ID: {{WECHAT_ID}}
        - Registered mobile number: {{CC}} {{PHONE}}
        - Country / region: {{COUNTRY}}, {{CITY}}
        - Contact email: {{EMAIL}}
        - Device: {{DEVICE}}, iOS {{IOS}}

        DETAILS
        1. On {{DATE}} the wallet was restricted with this message: "{{BAN}}".
        2. The funds in the wallet come from my own bank card and from red packets sent by family in {{CITY}}.
        3. I use WeChat Pay for groceries, transport and utilities in {{COUNTRY}}. The account has no shop, no collection business and no resale activity.
        4. The real-name information on the wallet matches my ID document, attached.

        REQUEST
        1. Please review the transaction history on this wallet and lift the restriction.
        2. If further verification is needed, please tell me which document to send and I will send it the same day.
        3. If the restriction stays, please release the balance to my verified bank card and confirm by email to {{EMAIL}}.

        Sincerely,
        {{NICKNAME}}
        WeChat ID {{WECHAT_ID}}
        """
    )
}
