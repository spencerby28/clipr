import SwiftUI

enum OnboardingPage: String, CaseIterable {
    case welcome = "bell.badge.fill"
    case capture = "camera.fill"
    case friends = "person.2.fill"
    case ready = "checkmark.circle.fill"
    
    var title: String {
        switch self {
        case .welcome: "Welcome to Clipr"
        case .capture: "Quick Capture Moments"
        case .friends: "Share With Friends"
        case .ready: "Ready to Start?"
        }
    }
    
    var subTitle: String {
        switch self {
        case .welcome: "Get ready for a new way to share authentic moments"
        case .capture: "Once a day, you'll get a surprise notification.\nYou'll have 3 seconds to capture both sides of the moment"
        case .friends: "See what your friends are up to with their daily clips"
        case .ready: "Let's set up your profile and get started!"
        }
    }
    
    // Add styling properties
    var symbolSize: CGFloat { 100 }
    var symbolWeight: Font.Weight { .bold }
    var symbolColor: Color { .burntSienna }
    var animationDuration: Double { 0.4 }
    
    var index: Int { OnboardingPage.allCases.firstIndex(of: self) ?? 0 }
    
    var nextPage: OnboardingPage {
        let nextIndex = index + 1
        return nextIndex < OnboardingPage.allCases.count ? OnboardingPage.allCases[nextIndex] : self
    }
    
    var previousPage: OnboardingPage {
        let prevIndex = index - 1
        return prevIndex >= 0 ? OnboardingPage.allCases[prevIndex] : self
    }
} 