import SwiftUI

class NavigationState: ObservableObject {
    enum Tab: Int {
        case feed, camera, profile
    }
    
    @Published var selectedTab: Tab = .feed
    @Published var isLoggedIn: Bool = false
    @Published var isCheckingAuth: Bool = true
    @Published var hasSeenOnboarding: Bool = false
    @Published var showTabMenu: Bool = false
    private let appwrite = Appwrite()
    
    init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    @MainActor
    func checkAuthStatus() async {
        isCheckingAuth = true
        isLoggedIn = await appwrite.checkSession()
        isCheckingAuth = false
    }
    
    @MainActor
    func signOut() async {
        do {
            try await appwrite.onLogout()
            isLoggedIn = false
        } catch {
            print("Logout error: \(error)")
        }
    }
    
    func completeOnboarding() {
        hasSeenOnboarding = true
    }
    
    func navigateTo(_ tab: Tab) {
        selectedTab = tab
    }
    
    var tabMenuItems: [(title: String, icon: String, tab: Tab)] {
        [
            ("Feed", "play.square.fill", .feed),
            ("Camera", "camera.fill", .camera),
            ("Profile", "person.fill", .profile)
        ]
    }
} 