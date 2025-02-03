import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "play.square")
                }
                .tag(NavigationState.Tab.feed)
            
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
                .tag(NavigationState.Tab.camera)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(NavigationState.Tab.profile)
        }
    }
} 