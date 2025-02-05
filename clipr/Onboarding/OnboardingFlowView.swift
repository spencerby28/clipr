import SwiftUI

enum OnboardingStep: Equatable {
    case phoneAuth
    case profileDetails
}

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .phoneAuth
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        NavigationStack {
            VStack {
                switch currentStep {
                case .phoneAuth:
                    OnboardingPhoneAuthView(onVerificationComplete: {
                        withAnimation {
                            currentStep = .profileDetails
                        }
                    })
                    
                case .profileDetails:
                    OnboardingDetailsView(
                        onOnboardingComplete: {
                            print("[OnboardingFlowView.swift] Profile setup completed")
                            navigationState.isLoggedIn = true
                        }
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == .profileDetails {
                        Button(action: {
                            withAnimation {
                                currentStep = .phoneAuth
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.outerSpace)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(NavigationState())
} 