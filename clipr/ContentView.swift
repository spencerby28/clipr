//
//  ContentView.swift
//  clipr
//
//  Created by Spencer Byrne on 2/3/25.
//

import SwiftUI

class ViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
}

struct ContentView: View {
    @StateObject private var navigationState = NavigationState()
    
    var body: some View {
        Group {
            if navigationState.isLoggedIn {
                MainTabView()
                    .environmentObject(navigationState)
            } else if !navigationState.hasSeenOnboarding {
                OnboardingIntroView()
                    .environmentObject(navigationState)
            } else {
                OnboardingFlowView()
                    .environmentObject(navigationState)
            }
        }
        // Force the view hierarchy to reset when the auth state changes
        .id(navigationState.isLoggedIn ? "LoggedIn" : "LoggedOut")
        .onAppear {
            print("[ContentView.swift] ContentView appeared – checking login status")
        }
    }
}

#Preview {
    ContentView()
}
