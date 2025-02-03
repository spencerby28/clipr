import SwiftUI

class NavigationState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var selectedTab: Tab = .feed
    @Published var isCheckingAuth: Bool = true
    private let appwrite = Appwrite()
    
    enum Tab {
        case feed
        case camera
        case profile
    }
    
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
} 