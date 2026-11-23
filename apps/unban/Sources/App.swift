import SwiftUI

@main
struct UnbanApp: App {
    init() {
        AppProxy.warmUp()
        LogStore.shared.log("启动 跨境解封助手 \(Bundle.main.appVer)")
        LogStore.shared.log("注入完成 uid=\(getuid())")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

extension Bundle {
    var appVer: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v)(\(b))"
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("总览", systemImage: "shield.lefthalf.filled") }
            EnvView()
                .tabItem { Label("环境", systemImage: "antenna.radiowaves.left.and.right") }
            CleanView()
                .tabItem { Label("清指纹", systemImage: "trash.fill") }
            AppealView()
                .tabItem { Label("申诉", systemImage: "doc.text.fill") }
            WebPanelView()
                .tabItem { Label("安全中心", systemImage: "safari.fill") }
        }
    }
}
