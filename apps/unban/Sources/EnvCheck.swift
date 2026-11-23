import Foundation
import UIKit
import Combine

struct IPInfo {
    var query = ""
    var country = ""
    var countryCode = ""
    var regionName = ""
    var city = ""
    var isp = ""
    var timezone = ""
    var hosting = false
    var proxyFlag = false

    var summary: String {
        let loc = [country, regionName, city].filter { !$0.isEmpty }.joined(separator: "/")
        return "\(query)  \(loc.isEmpty ? "-" : loc)  \(isp)"
    }
}

struct ProxyConfig: Codable, Equatable {
    var enabled = false
    var host = ""
    var port = 1080
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var proxy: ProxyConfig {
        didSet { save() }
    }

    @Published var lastRegion: String {
        didSet { UserDefaults.standard.set(lastRegion, forKey: "lastRegion") }
    }

    private init() {
        let d = UserDefaults.standard
        if let raw = d.data(forKey: "proxy"), let p = try? JSONDecoder().decode(ProxyConfig.self, from: raw) {
            proxy = p
        } else {
            proxy = ProxyConfig()
        }
        lastRegion = d.string(forKey: "lastRegion") ?? "SG"
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(proxy) {
            UserDefaults.standard.set(raw, forKey: "proxy")
        }
    }
}

enum EnvCheck {
    static let wechatID = "com.tencent.xin"
    static let groupID = "group.com.tencent.xin"

    struct WeChatInfo {
        var bundlePath = ""
        var version = ""
        var dataPath = ""
        var groupPath = ""
        var dataSize: Int64 = 0
        var installed = false
    }

    static func wechat() -> WeChatInfo {
        var info = WeChatInfo()

        if let p = AppProxy.bundleURL(wechatID) { info.bundlePath = p }
        if info.bundlePath.isEmpty, let p = scanBundles()[wechatID] { info.bundlePath = p }
        info.installed = !info.bundlePath.isEmpty
        if let d = NSDictionary(contentsOfFile: info.bundlePath + "/Info.plist") {
            info.version = (d["CFBundleShortVersionString"] as? String) ?? ""
        }

        if let p = AppProxy.dataURL(wechatID) { info.dataPath = p }
        if info.dataPath.isEmpty,
           let p = Bridge.containers(in: "/var/mobile/Containers/Data/Application")[wechatID] {
            info.dataPath = p
        }
        if let p = Bridge.containers(in: "/var/mobile/Containers/Shared/AppGroup")[groupID] {
            info.groupPath = p
        }
        if !info.dataPath.isEmpty { info.dataSize = Bridge.size(info.dataPath) }
        return info
    }

    static func scanBundles() -> [String: String] {
        var out: [String: String] = [:]
        let root = "/var/containers/Bundle/Application"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { return out }
        for d in dirs {
            let base = root + "/" + d
            guard let apps = try? FileManager.default.contentsOfDirectory(atPath: base) else { continue }
            for a in apps where a.hasSuffix(".app") {
                let p = base + "/" + a
                if let dict = NSDictionary(contentsOfFile: p + "/Info.plist"),
                   let bid = dict["CFBundleIdentifier"] as? String {
                    out[bid] = p
                }
            }
        }
        return out
    }

    static func localeSummary() -> String {
        let l = Locale.current
        let region = l.regionCode ?? "??"
        let langs = Locale.preferredLanguages.prefix(2).joined(separator: ",")
        return "\(region) · \(l.identifier) · \(langs) · \(TimeZone.current.identifier)"
    }

    static func ipInfo(proxy: ProxyConfig, timeout: TimeInterval = 12, completion: @escaping (IPInfo?) -> Void) {
        var dict: [AnyHashable: Any] = [:]
        if proxy.enabled, !proxy.host.isEmpty, proxy.port > 0 {
            dict["SOCKSEnable"] = 1
            dict["SOCKSProxy"] = proxy.host
            dict["SOCKSPort"] = proxy.port
        }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        if !dict.isEmpty { cfg.connectionProxyDictionary = dict }

        let urlStr = "http://ip-api.com/json/?fields=status,message,query,country,countryCode,regionName,city,isp,timezone,proxy,hosting&lang=zh-CN"
        guard let url = URL(string: urlStr) else { completion(nil); return }

        URLSession(configuration: cfg).dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["status"] as? String) == "success" else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            var i = IPInfo()
            i.query = (obj["query"] as? String) ?? ""
            i.country = (obj["country"] as? String) ?? ""
            i.countryCode = (obj["countryCode"] as? String) ?? ""
            i.regionName = (obj["regionName"] as? String) ?? ""
            i.city = (obj["city"] as? String) ?? ""
            i.isp = (obj["isp"] as? String) ?? ""
            i.timezone = (obj["timezone"] as? String) ?? ""
            i.hosting = (obj["hosting"] as? Bool) ?? false
            i.proxyFlag = (obj["proxy"] as? Bool) ?? false
            DispatchQueue.main.async { completion(i) }
        }.resume()
    }
}
