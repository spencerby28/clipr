import SwiftUI

class NavigationState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var selectedTab: Tab = .feed
    
    enum Tab {
        case feed
        case camera
        case profile
    }
} 