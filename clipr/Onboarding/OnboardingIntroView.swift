import SwiftUI

struct OnboardingIntroView: View {
    @State private var activePage: OnboardingPage = .welcome
    @EnvironmentObject var navigationState: NavigationState
    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                
                // Animated Icon
                OnboardingSymbolView(page: activePage)
                    .offset(x: dragOffset)
                    .animation(.interactiveSpring(), value: dragOffset)
                
                // Page Content
                VStack(spacing: 12) {
                    Text(activePage.title)
                        .font(.title.bold())
                        .foregroundColor(.outerSpace)
                        .multilineTextAlignment(.center)
                    
                    Text(activePage.subTitle)
                        .font(.body)
                        .foregroundColor(.cadetGray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .offset(x: dragOffset)
                .animation(.interactiveSpring(), value: dragOffset)
                
                Spacer(minLength: 0)
                
                // Page Indicators
                PageIndicator(currentPage: activePage)
                
                // Navigation Button
                Button(action: handleNavigation) {
                    Text(activePage == .ready ? "Get Started" : "Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.burntSienna)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(Color.dimGray.opacity(0.1))
            .animation(.smooth, value: activePage)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width / 3
                    }
                    .onEnded { value in
                        let threshold = geometry.size.width * 0.2
                        if value.translation.width < -threshold && activePage != .ready {
                            handleNavigation()
                        } else if value.translation.width > threshold && activePage != .welcome {
                            activePage = activePage.previousPage
                        }
                    }
            )
        }
    }
    
    private func handleNavigation() {
        if activePage == .ready {
            navigationState.completeOnboarding()
        } else {
            activePage = activePage.nextPage
        }
    }
}

#Preview {
    OnboardingIntroView()
        .environmentObject(NavigationState())
} 