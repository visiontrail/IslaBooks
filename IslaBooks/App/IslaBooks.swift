import SwiftUI
import CloudKit

@main
struct IslaBooksApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var appConfiguration = AppConfiguration()
    @StateObject private var syncService = SyncService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appConfiguration)
                .environmentObject(syncService)
                .onAppear {
                    setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    persistenceController.save()
                }
        }
    }
    
    private func setupApp() {
        // 初始化应用配置
        configureCloudKit()
        configureAppearance()
        configureAnalytics()
    }
    
    private func configureCloudKit() {
        syncService.initialize()
    }
    
    private func configureAppearance() {
        // 配置全局UI样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // 配置TabBar样式
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    private func configureAnalytics() {
        #if DEBUG
        print("Debug mode: Analytics disabled")
        #else
        // 配置分析服务
        AnalyticsService.shared.initialize()
        #endif
    }
}

