import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navigationState: NavigationState
    @State private var longPressLocation: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                switch navigationState.selectedTab {
                case .feed:
                    FeedView()
                case .camera:
                    CameraView()
                case .profile:
                    ProfileView()
                }
            }
            .onTapGesture {
                // Single tap cycles through tabs
                let currentRawValue = navigationState.selectedTab.rawValue
                let nextRawValue = (currentRawValue + 1) % 3
                navigationState.selectedTab = NavigationState.Tab(rawValue: nextRawValue) ?? .feed
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { _ in
                        navigationState.showTabMenu = true
                    }
            )
            
            // Menu overlay
            if navigationState.showTabMenu {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        navigationState.showTabMenu = false
                    }
                
                VStack(spacing: 20) {
                    ForEach(navigationState.tabMenuItems, id: \.title) { item in
                        Button(action: {
                            navigationState.navigateTo(item.tab)
                            navigationState.showTabMenu = false
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: item.icon)
                                    .font(.title2)
                                Text(item.title)
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(navigationState.selectedTab == item.tab ? Color.accentColor : Color.gray.opacity(0.3))
                            )
                        }
                    }
                }
                .padding(.horizontal, 32)
                .transition(.scale)
                .animation(.spring(), value: navigationState.showTabMenu)
            }
        }
    }
} 