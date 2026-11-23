import Foundation
import UIKit

// LSApplicationWorkspace 私有桥，拿微信的 bundle / data 容器
enum AppProxy {
    private static var loaded = false

    static func warmUp() {
        guard !loaded else { return }
        let paths = [
            "/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices",
            "/System/Library/PrivateFrameworks/CoreServices.framework/CoreServices",
            "/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices"
        ]
        for p in paths { _ = dlopen(p, RTLD_NOW) }
        loaded = true
    }

    private static func workspace() -> AnyObject? {
        warmUp()
        guard let cls = NSClassFromString("LSApplicationWorkspace") else { return nil }
        let sel = NSSelectorFromString("defaultWorkspace")
        guard (cls as AnyObject).responds(to: sel) else { return nil }
        return (cls as AnyObject).perform(sel)?.takeUnretainedValue()
    }

    static func proxy(_ bundleID: String) -> AnyObject? {
        guard let ws = workspace() else { return nil }
        let sel = NSSelectorFromString("applicationProxyForIdentifier:")
        guard ws.responds(to: sel) else { return nil }
        return ws.perform(sel, with: bundleID)?.takeUnretainedValue()
    }

    static func bundleURL(_ bundleID: String) -> String? {
        guard let p = proxy(bundleID) else { return nil }
        return (p.value(forKey: "bundleURL") as? URL)?.path
    }

    static func dataURL(_ bundleID: String) -> String? {
        guard let p = proxy(bundleID) else { return nil }
        return (p.value(forKey: "dataContainerURL") as? URL)?.path
    }
}

enum Bridge {
    static let fm = FileManager.default

    // MARK: - 进程

    @discardableResult
    static func run(_ path: String, _ args: [String] = []) -> String {
        guard fm.isExecutableFile(atPath: path) else { return "跳过: \(path) 没执行权限" }
        var pid = pid_t()
        let argvStrings: [String] = [path] + args
        var argv: [UnsafeMutablePointer<CChar>?] = argvStrings.map { strdup($0) }
        argv.append(nil)
        let envStrings: [String] = ["PATH=/usr/bin:/bin:/usr/sbin:/sbin", "HOME=/var/mobile"]
        var envp: [UnsafeMutablePointer<CChar>?] = envStrings.map { strdup($0) }
        envp.append(nil)
        let rc = posix_spawn(&pid, path, nil, nil, argv, envp)
        argv.forEach { free($0) }
        envp.forEach { free($0) }
        guard rc == 0 else { return "spawn 失败 rc=\(rc)" }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return "exit=\(status >> 8)"
    }

    @discardableResult
    static func kill(_ proc: String) -> String {
        run("/usr/bin/killall", ["-9", proc])
    }

    static func openURL(_ s: String) {
        guard let u = URL(string: s) else { return }
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(u) {
                UIApplication.shared.open(u, options: [:], completionHandler: nil)
            }
        }
    }

    // MARK: - 容器

    static func containers(in root: String) -> [String: String] {
        var out: [String: String] = [:]
        guard let dirs = try? fm.contentsOfDirectory(atPath: root) else { return out }
        for d in dirs {
            let p = root + "/" + d
            let meta = p + "/.com.apple.mobile_container_manager.metadata.plist"
            guard let dict = NSDictionary(contentsOfFile: meta) else { continue }
            let id = (dict["MCMMetadataIdentifier"] as? String) ?? d
            out[id] = p
        }
        return out
    }

    static func size(_ path: String) -> Int64 {
        guard let e = fm.enumerator(atPath: path) else { return 0 }
        var total: Int64 = 0
        for case let rel as String in e {
            let full = path + "/" + rel
            if let a = try? fm.attributesOfItem(atPath: full), let n = a[.size] as? NSNumber {
                total += n.int64Value
            }
        }
        return total
    }

    static func mkdirs(_ path: String) {
        try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    static func clone(_ src: String, to dst: String) -> Bool {
        guard fm.fileExists(atPath: src) else { return false }
        mkdirs((dst as NSString).deletingLastPathComponent)
        do {
            if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
            try fm.copyItem(atPath: src, toPath: dst)
            return true
        } catch {
            return false
        }
    }

    static func wipe(_ path: String) -> Bool {
        guard fm.fileExists(atPath: path) else { return false }
        do { try fm.removeItem(atPath: path); return true } catch { return false }
    }

    static func emptyDir(_ path: String) -> Bool {
        guard let kids = try? fm.contentsOfDirectory(atPath: path) else { return false }
        var ok = true
        for k in kids {
            if !wipe(path + "/" + k) { ok = false }
        }
        return ok
    }
}
