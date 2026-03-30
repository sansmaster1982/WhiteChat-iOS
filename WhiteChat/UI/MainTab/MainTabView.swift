import SwiftUI

/// Main tab navigation — matches Android BottomNavigation
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatsListView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text(L("tab_chats"))
                }
                .tag(0)

            ContactsListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text(L("tab_contacts"))
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text(L("tab_settings"))
                }
                .tag(2)
        }
        .accentColor(AppTheme.primary)
    }
}
