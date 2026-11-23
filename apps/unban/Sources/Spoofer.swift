import Foundation

struct RegionPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let locale: String
    let languages: [String]
    let tz: String
}

enum Spoofer {
    static let globalPrefs = "/var/mobile/Library/Preferences/.GlobalPreferences.plist"
    static let backupPrefs = "/var/mobile/Documents/GlobalPreferences.orig.plist"

    static let presets: [RegionPreset] = [
        .init(id: "SG", name: "新加坡", locale: "en_SG", languages: ["en-SG"], tz: "Asia/Singapore"),
        .init(id: "US", name: "美国", locale: "en_US", languages: ["en-US"], tz: "America/Los_Angeles"),
        .init(id: "MY", name: "马来西亚", locale: "ms_MY", languages: ["ms-MY"], tz: "Asia/Kuala_Lumpur"),
        .init(id: "TH", name: "泰国", locale: "th_TH", languages: ["th-TH"], tz: "Asia/Bangkok"),
        .init(id: "VN", name: "越南", locale: "vi_VN", languages: ["vi-VN"], tz: "Asia/Ho_Chi_Minh"),
        .init(id: "ID", name: "印尼", locale: "id_ID", languages: ["id-ID"], tz: "Asia/Jakarta"),
        .init(id: "PH", name: "菲律宾", locale: "en_PH", languages: ["en-PH"], tz: "Asia/Manila"),
        .init(id: "JP", name: "日本", locale: "ja_JP", languages: ["ja-JP"], tz: "Asia/Tokyo"),
        .init(id: "KR", name: "韩国", locale: "ko_KR", languages: ["ko-KR"], tz: "Asia/Seoul"),
        .init(id: "GB", name: "英国", locale: "en_GB", languages: ["en-GB"], tz: "Europe/London"),
        .init(id: "CA", name: "加拿大", locale: "en_CA", languages: ["en-CA"], tz: "America/Toronto"),
        .init(id: "AU", name: "澳洲", locale: "en_AU", languages: ["en-AU"], tz: "Australia/Sydney"),
        .init(id: "AE", name: "阿联酋", locale: "en_AE", languages: ["en-AE"], tz: "Asia/Dubai"),
        .init(id: "DE", name: "德国", locale: "de_DE", languages: ["de-DE"], tz: "Europe/Berlin"),
        .init(id: "CN", name: "中国（还原用）", locale: "zh_CN", languages: ["zh-Hans-CN"], tz: "Asia/Shanghai")
    ]

    static func preset(_ id: String) -> RegionPreset? {
        presets.first { $0.id == id }
    }

    static func backup(log: (String) -> Void) {
        if FileManager.default.fileExists(atPath: backupPrefs) {
            log("原始偏好已在 \(backupPrefs)，跳过备份")
            return
        }
        Bridge.mkdirs((backupPrefs as NSString).deletingLastPathComponent)
        if Bridge.clone(globalPrefs, to: backupPrefs) {
            log("已备份原始 .GlobalPreferences.plist")
        } else {
            log("原始 .GlobalPreferences.plist 读不到，直接往前写")
        }
    }

    @discardableResult
    static func apply(region: String, setLanguage: Bool, log: @escaping (String) -> Void) -> Bool {
        guard let p = preset(region) else {
            log("区域 \(region) 不在预设表里")
            return false
        }
        backup(log: log)

        CFPreferencesSetValue("AppleLocale" as CFString,
                             p.locale as CFString,
                             kCFPreferencesAnyApplication,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesAnyHost)
        if setLanguage {
            CFPreferencesSetValue("AppleLanguages" as CFString,
                                  p.languages as CFArray,
                                  kCFPreferencesAnyApplication,
                                  kCFPreferencesCurrentUser,
                                  kCFPreferencesAnyHost)
        }
        let synced = CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        log("CFPreferences 写入 AppleLocale=\(p.locale) 语言=\(setLanguage ? p.languages.joined(separator: ",") : "保持") sync=\(synced)")

        if let dict = NSMutableDictionary(contentsOfFile: globalPrefs) {
            dict["AppleLocale"] = p.locale
            if setLanguage { dict["AppleLanguages"] = p.languages }
            let ok = dict.write(toFile: globalPrefs, atomically: true)
            log("回写 \(globalPrefs) 结果=\(ok ? "成功" : "失败，靠 cfprefsd 生效")")
        } else {
            log("\(globalPrefs) 解析失败，只走 CFPreferences")
        }

        log("时区目标 \(p.tz)：/var/db/timezone 要 root，去 设置-通用-日期与时间 手动改成该城市")
        log("杀 cfprefsd / 2 秒后 respring SpringBoard")
        _ = Bridge.run("/usr/bin/killall", ["-9", "cfprefsd"])
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            _ = Bridge.kill("SpringBoard")
        }
        return true
    }

    static func restore(log: @escaping (String) -> Void) {
        guard let dict = NSDictionary(contentsOfFile: backupPrefs) else {
            log("没有备份文件 \(backupPrefs)，改回 cn_CN 收尾")
            _ = Spoofer.apply(region: "CN", setLanguage: false, log: log)
            return
        }
        _ = dict.write(toFile: globalPrefs, atomically: true)
        log("已还原原始 .GlobalPreferences.plist")
        _ = Bridge.run("/usr/bin/killall", ["-9", "cfprefsd"])
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            _ = Bridge.kill("SpringBoard")
        }
    }
}
