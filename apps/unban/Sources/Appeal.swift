import Foundation

struct AppealInput {
    var wxid = ""
    var nickname = ""
    var cc = "+65"
    var phone = ""
    var region = "新加坡"
    var city = "Singapore"
    var reason = "登录环境异常"
    var date = ""
    var device = "iPhone"
    var ios = ""
}

enum Appeal {
    static func chinese(_ i: AppealInput) -> String {
        """
        微信安全中心：
        本人微信账号 \(i.wxid.isEmpty ? "[微信号]" : i.wxid)（昵称 \(i.nickname.isEmpty ? "[昵称]" : i.nickname)），
        绑定手机 \(i.cc) \(i.phone)，长期在 \(i.region) \(i.city) 工作生活。
        \(i.date) 登录时提示“\(i.reason)”，账号被限制登录，至今没有恢复。

        情况说明：
        1. 本人常驻 \(i.region)，日常使用当地号码 \(i.cc) \(i.phone) 与当地网络，登录设备为 \(i.device)（iOS \(i.ios)），
           属正常跨境使用，不是代登录、不是买卖账号。
        2. 账号全程本人使用，未做过群发、加粉、营销导流、外挂插件、批量注册、自动抢红包这类操作。
        3. 未把账号、验证码交给任何人代操作，也未在陌生设备上登录。

        申请事项：恢复账号正常登录，请通过海外号码通道下发短信验证码。

        可核验信息：
        - 手机号 \(i.cc) \(i.phone) 可正常接收短信，随时可验证；
        - 常用登录城市 \(i.city)，常用设备 \(i.device) / iOS \(i.ios)；
        - 实名信息、历史支付与红包记录与本人一致，需要可提供截图；
        - 如需本人手持证件照或当地居住证明，可按要求补交。

        承诺：账号恢复后仅本人使用，不再异地频繁切换设备与网络。
        谢谢。
        """
    }

    static func english(_ i: AppealInput) -> String {
        """
        To WeChat Security Center,

        My WeChat ID is \(i.wxid.isEmpty ? "[WeChat ID]" : i.wxid) (nickname \(i.nickname.isEmpty ? "[nickname]" : i.nickname)), 
        registered with phone number \(i.cc) \(i.phone). I have been living and working in \(i.city), \(i.region).

        On \(i.date) the app showed "\(i.reason)" and my account has been restricted from logging in since then.

        1. I am based in \(i.region) and use a local number (\(i.cc) \(i.phone)) and local network. My device is \(i.device) running iOS \(i.ios). 
           This is normal cross-border usage, not account sharing or resale.
        2. The account is used only by me. No mass messaging, no marketing, no third-party plugins, no bulk registration, no automation.
        3. I never shared my password or SMS codes with anyone and never logged in on unknown devices.

        Request: please restore login access and send the verification code to my overseas number above.

        Verifiable details:
        - \(i.cc) \(i.phone) receives SMS normally;
        - usual login city \(i.city), usual device \(i.device) / iOS \(i.ios);
        - real-name and payment history match my identity, screenshots available on request;
        - I can provide ID photo or local residence proof if required.

        Thank you.
        """
    }

    static func friendScript(_ i: AppealInput) -> String {
        """
        【微信辅助验证，帮个忙，2 分钟内有效】

        我这号被限制登录了，需要一位好友做辅助验证。

        操作路径：微信 → 搜索“微信团队” → 左下角“自助工具” → “辅助验证” → 输入我的手机号 \(i.cc) \(i.phone) → 按提示点确认。

        你这边要满足：
        1. 账号注册满 6 个月，已实名；
        2. 近 1 个月没有帮别人辅助过，今天没被封过号；
        3. 和我是双向好友，且没有把我删掉。

        全程不用给我验证码，你只在自己手机上点确认。弄完回我一句“好了”，谢谢。
        """
    }

    static func smsFlow(_ i: AppealInput) -> String {
        """
        一、微信内自助解封（首选）
        1. 打开微信，登录页弹出限制提示，点“确定”。
        2. 点“前往微信安全中心” → “账号解封 / 解封账号”。
        3. 输入手机号：\(i.cc) \(i.phone)（海外号直接填国家码 + 号码，不要加 0）。
        4. 收短信 → 填 6 位验证码 → 下一步。
        5. 页面要求好友辅助时，把“申诉 → 好友辅助文案”发给满足条件的好友，让对方 2 分钟内操作。
        6. 解封成功后立刻在“我 → 设置 → 账号与安全 → 登录设备管理”里删掉不认识的设备。

        二、网页通道（微信内入口被卡住时用）
        1. 本 App “安全中心”页，或 Safari 打开 weixin110.qq.com。
        2. 选“账号安全” → “账号解封/申诉”。
        3. 表单填：微信号 \(i.wxid)、手机 \(i.cc) \(i.phone)、常驻地区 \(i.region)、封禁提示原文“\(i.reason)”。
        4. 申诉内容粘贴“申诉 → 中文申诉文案”，附件加上：当地号码话费账单截图、当地居住/工作证明、常用设备截图。
        5. 提交后记下申诉单号，24–72 小时出结果。

        三、被驳回之后的节奏
        1. 第一次驳回后停 15 天再提，同一设备连续提交会叠加风控。
        2. 第二次提交换成纯英文申诉文案 + 上传当地证件，走海外人工通道。
        3. 第 15 天那次仍然驳回，换一台没登录过该账号的干净设备 + 另一个海外出口 IP 再提一次。
        """
    }

    static func noFriend(_ i: AppealInput) -> String {
        """
        找不到合格好友 → 按这六条顺序试，前一条堵住就往下走：

        一、短信直解（不碰好友环节）
        1. 微信登录页 → 限制提示 → “确定” → “前往微信安全中心” → “解封账号”。
        2. 手机号填 \(i.cc) \(i.phone) → 收码 → 提交。
        3. 弹出“请好友辅助验证”时，找页面上的“其他验证方式 / 换一种方式 / 暂不验证”，
           点进去多数版本会放出“实名校验”或“人脸验证”。

        二、人脸 / 实名校验（账号本人实名的走这条）
        1. 同一页选“身份验证” → “人脸识别”。
        2. 正对光、别戴口罩帽子，按提示眨眼转头；一次不过换自然光重来，别连刷超过 3 次。
        3. 通过后人脸结果直接进风控，好友环节被跳过。

        三、微信支付实名校验
        1. 页面出现“验证微信支付实名信息”：姓名 + 身份证号 + 绑定银行卡后 8 位。
        2. 没绑卡就先在另一台能登录的设备上绑一张本人卡，满 24 小时再回来试。

        四、人工工单（前三条全堵死时的正路）
        1. 本 App“安全中心”页开 weixin110.qq.com → 账号安全 → 账号申诉 / 解封申诉。
        2. 验证方式一栏选“人工审核 / 提交材料”，材料一次交齐：
           - \(i.cc) \(i.phone) 近 3 个月话费账单（截图要带姓名与号码）
           - 证件正反面 + 手持证件照
           - \(i.region) \(i.city) 的居住或工作证明（租房合同、工牌、学生证、水电单，任一份）
           - 常用设备截图：设置-通用-关于本机 + 微信“登录设备管理”页
           - 账号近期聊天或朋友圈截图 2-3 张，证明是活人在用
        3. 正文用“中文申诉”那份，末尾追加一句：本人无可协助验证的好友，申请以人工材料核验方式解封。
        4. 记下单号，72 小时出结果，驳回停 15 天再提。

        五、账号申诉找回路（被盗导致封禁专用，最多人漏掉这条）
        1. weixin110 → “找回账号密码” → “账号申诉”。
        2. 验证项：曾用密码、常用登录设备、绑定银行卡后 8 位、注册时间与地点。
        3. 过了直接重置密码，登录限制一起解除，全程不用任何好友点确认。

        六、电话兜底
        腾讯客服 0755-83765566，境外 +86 755 8376 5566，工作日 9:00-21:00 有人工。
        开场原话：我的账号 \(i.wxid) 在 \(i.region) 被限制登录，没有可辅助验证的好友，
        申请人工核验解封，材料已全部备好，现在可以发给你们。
        """
    }

    static func checklist() -> String {
        """
        提交前逐项过一遍，缺一项就先去补齐：

        [ ] 出口 IP 在目标国家，且不是机房 IP（本 App 环境页看 hosting 字段，要是“否”）
        [ ] 手机号是该国真实号码，能收短信，且没给别的微信号做过验证
        [ ] 设备已清过指纹（本 App 清指纹页：偏好 + 缓存 + WechatPrivate + AppGroup）
        [ ] 系统区域已改成目标国家并 respring 过
        [ ] 微信是 App Store 目标区账号下载的版本，不是国内版覆盖安装
        [ ] 申诉文案里的城市、号码、证件三处信息互相一致
        [ ] 一次只提交一个渠道，微信内提交了就别同时提网页工单

        时间线：提交 → 24h 内看是否进入人工 → 72h 出结果 → 驳回等 15 天 → 换环境再提。
        全程同一账号不要超过 3 次提交。
        """
    }
}
