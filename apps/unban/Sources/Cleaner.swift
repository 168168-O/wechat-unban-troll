import Foundation

struct CleanOptions {
    var prefs = true
    var caches = true
    var wechatPrivate = true
    var chatDB = false
    var group = true
    var wholeContainer = false
    var backup = true
}

enum Cleaner {
    struct Item {
        let label: String
        let path: String
        let heavy: Bool
    }

    static func backupRoot() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "/var/mobile/Documents/WeChatUnbanBackup/" + f.string(from: Date())
    }

    static func items(_ info: EnvCheck.WeChatInfo, _ o: CleanOptions) -> [Item] {
        var out: [Item] = []
        let d = info.dataPath
        if o.prefs {
            out.append(Item(label: "偏好", path: d + "/Library/Preferences", heavy: false))
        }
        if o.caches {
            out.append(Item(label: "缓存", path: d + "/Library/Caches", heavy: false))
            out.append(Item(label: "tmp", path: d + "/tmp", heavy: false))
            out.append(Item(label: "WebKit 缓存", path: d + "/Library/WebKit", heavy: false))
        }
        if o.wechatPrivate {
            out.append(Item(label: "WechatPrivate 指纹库", path: d + "/Library/WechatPrivate", heavy: false))
            out.append(Item(label: "MMKV/日志", path: d + "/Library/mmkv", heavy: false))
            out.append(Item(label: "Log", path: d + "/Library/Log", heavy: false))
        }
        if o.chatDB {
            out.append(Item(label: "Documents 聊天库", path: d + "/Documents", heavy: true))
        }
        return out
    }

    static func groupItems(_ info: EnvCheck.WeChatInfo, _ o: CleanOptions) -> [Item] {
        guard o.group, !info.groupPath.isEmpty else { return [] }
        return [
            Item(label: "AppGroup 缓存", path: info.groupPath + "/Library/Caches", heavy: false),
            Item(label: "AppGroup 偏好", path: info.groupPath + "/Library/Preferences", heavy: false)
        ]
    }

    static func execute(info: EnvCheck.WeChatInfo,
                        opts: CleanOptions,
                        log: @escaping (String) -> Void,
                        done: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard !info.dataPath.isEmpty else {
                done("没找到微信数据容器，先把微信装好并至少启动一次")
                return
            }

            log("杀微信进程")
            log(Bridge.kill("Weixin"))
            log(Bridge.kill("WeChat"))
            Thread.sleep(forTimeInterval: 1.0)

            var plan = items(info, opts)
            plan.append(contentsOf: groupItems(info, opts))
            if opts.wholeContainer {
                plan.append(Item(label: "整容器内容", path: info.dataPath, heavy: true))
            }

            var backupDir: String?
            if opts.backup {
                let root = backupRoot()
                Bridge.mkdirs(root)
                log("备份目录 \(root)")
                for it in plan where !it.heavy {
                    let rel = it.path.hasPrefix(info.dataPath) ?
                        String(it.path.dropFirst(info.dataPath.count)) :
                        "/group" + it.path
                    let dst = root + "/" + it.label.replacingOccurrences(of: " ", with: "_") + rel
                    let ok = Bridge.clone(it.path, to: dst)
                    log("备份 \(it.label) → \(ok ? "完成" : "空/失败")")
                }
                backupDir = root
            }

            for it in plan {
                if it.label == "整容器内容" {
                    let ok = Bridge.emptyDir(it.path)
                    log("清空整容器内容 → \(ok ? "完成" : "有残留")")
                } else {
                    let ok = Bridge.wipe(it.path)
                    log("删除 \(it.label) → \(ok ? "完成" : "不存在")")
                }
            }

            log("清指纹收尾完成，微信下次启动会重建设备指纹")
            done(backupDir)
        }
    }
}
