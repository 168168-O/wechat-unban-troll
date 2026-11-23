import SwiftUI

@main
struct ENTemplateApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var store = FormStore()

    var body: some View {
        TabView {
            FormView().environmentObject(store)
                .tabItem { Label("表单", systemImage: "square.and.pencil") }
            TemplateView().environmentObject(store)
                .tabItem { Label("模板", systemImage: "doc.text") }
            OverseasView().environmentObject(store)
                .tabItem { Label("海外入口", systemImage: "globe") }
            FlowView().environmentObject(store)
                .tabItem { Label("流程", systemImage: "list.number") }
        }
    }
}
