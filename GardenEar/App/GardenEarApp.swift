import SwiftUI

extension Notification.Name {
    static let sightingSaved = Notification.Name("com.gardenear.sightingSaved")
}

@main
struct GardenEarApp: App {
    init() {
        try? DatabaseManager.shared.setup()

        // Remove the hairline separator above the tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Remove the hairline shadow below the navigation bar
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("Record", systemImage: "mic.fill") }
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
            MapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
            ScoreView()
                .tabItem { Label("Score", systemImage: "leaf.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.primary)
    }
}
