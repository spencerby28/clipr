import SwiftUI

class NavigationState: ObservableObject {
    static let shared = NavigationState()
    
    enum Tab: Int {
        case feed = 0
        case camera = 1
        case profile = 2
        
    }
    
    @Published var selectedTab: Tab = .feed
    @Published var isLoggedIn: Bool = false {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    @Published var isCheckingAuth: Bool = true
    @Published var hasSeenOnboarding: Bool = false
    @Published var showTabMenu: Bool = false
    private let appwrite = Appwrite()
    
    private init() {
        // Load saved login state
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        
        // Still check auth status in background
        Task {
            await checkAuthStatus()
        }
    }
    
    @MainActor
    func checkAuthStatus() async {
        print("checking auth current value is: ")
        print(self.isLoggedIn)
        isCheckingAuth = true
        let authStatus = await appwrite.checkSession()
        
        // Only update if different to avoid unnecessary UI updates
        if authStatus != isLoggedIn {
            isLoggedIn = authStatus
        }
        isCheckingAuth = false
    }
    
    @MainActor
    func signOut() async {
        do {
            try await appwrite.onLogout()
            isLoggedIn = false
            // Clear any cached user data
            UserDefaults.standard.removeObject(forKey: "isLoggedIn")
            UserDefaults.standard.removeObject(forKey: "cachedUser")
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
