import SwiftUI

enum OnboardingStep: Equatable {
    case tutorial
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
                case .tutorial:
                    OnboardingIntroView()
                        .background(Color.init(hex: "#FFF8F0"))
                case .phoneAuth:
                    OnboardingPhoneAuthView(
                        onVerificationComplete: {
                            withAnimation {
                                currentStep = .profileDetails
                            }
                        }
                    )
                    .background(Color.init(hex: "#FFF8F0"))
                case .profileDetails:
                    OnboardingDetailsView(
                        onOnboardingComplete: {
                            print("[OnboardingFlowView.swift] Profile setup completed")
                            navigationState.isLoggedIn = true
                        }
                    )
                    .background(Color.init(hex: "#FFF8F0"))
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .tutorial {
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
        .preferredColorScheme(.light)
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(NavigationState.shared)
        .background(Color.init(hex: "#FFF8F0"))
}
