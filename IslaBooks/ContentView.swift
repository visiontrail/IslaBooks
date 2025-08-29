import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfiguration: AppConfiguration
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoveryView()
                .tabItem {
                    Image(systemName: "star.fill")
                    Text("发现")
                }
                .tag(0)
            
            LibraryView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("书架")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(2)
        }
        .accentColor(Color("AccentColor"))
        .onAppear {
            if appConfiguration.isFirstLaunch {
                setupFirstLaunch()
            }
        }
    }
    
    private func setupFirstLaunch() {
        // 首次启动的设置
        appConfiguration.completeFirstLaunch()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppConfiguration())
        .environmentObject(SyncService())
}

