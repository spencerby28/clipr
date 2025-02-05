import SwiftUI
import Combine

enum OnboardingStep: Equatable {
    case tutorial
    case phoneAuth
    case profileSetup
}

@MainActor
class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .tutorial
    @Published var isComplete: Bool = false
    
    // User data
    @Published var phoneNumber: String = ""
    @Published var verificationID: String = ""
    @Published var username: String = ""
    @Published var profileImage: UIImage?
    
    // Tutorial state
    @Published var currentTutorialPage: Int = 0
    let totalTutorialPages: Int = 4
    
    // Loading and error states
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    func advance() {
        switch currentStep {
        case .tutorial:
            currentStep = .phoneAuth
        case .phoneAuth:
            currentStep = .profileSetup
        case .profileSetup:
            isComplete = true
        }
    }
    
    func goBack() {
        switch currentStep {
        case .tutorial:
            break // Already at first step
        case .phoneAuth:
            currentStep = .tutorial
        case .profileSetup:
            currentStep = .phoneAuth
        }
    }
}

struct OnboardingCoordinator: View {
    @StateObject private var state = OnboardingState()
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        NavigationStack {
            Group {
                switch state.currentStep {
                case .tutorial:
                    TutorialView()
                case .phoneAuth:
                    PhoneAuthView()
                case .profileSetup:
                    ProfileSetupView()
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if state.currentStep != .tutorial {
                        Button(action: { state.goBack() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.outerSpace)
                        }
                    }
                }
            }
        }
        .environmentObject(state)
        .onChange(of: state.isComplete) { newValue in
            if newValue {
                navigationState.isLoggedIn = true
            }
        }
    }
}

#Preview {
    OnboardingCoordinator()
        .environmentObject(NavigationState())
} 