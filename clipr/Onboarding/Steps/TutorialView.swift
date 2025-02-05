import SwiftUI

struct TutorialPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbolName: String
}

struct TutorialView: View {
    @EnvironmentObject private var state: OnboardingState
    
    private let pages: [TutorialPage] = [
        TutorialPage(
            title: "Welcome to Clipr",
            subtitle: "Share your moments with the world through short, engaging videos",
            symbolName: "video.fill"
        ),
        TutorialPage(
            title: "Create & Share",
            subtitle: "Record and edit amazing videos with powerful tools",
            symbolName: "wand.and.stars"
        ),
        TutorialPage(
            title: "Connect",
            subtitle: "Join a community of creators and find your audience",
            symbolName: "person.2.fill"
        ),
        TutorialPage(
            title: "Ready to Start?",
            subtitle: "Let's set up your account and get you creating",
            symbolName: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                
                // Animated Icon
                MorphingSymbolView(
                    symbolName: pages[state.currentTutorialPage].symbolName
                )
                .font(.system(size: 80))
                .foregroundColor(.burntSienna)
                
                // Page Content
                VStack(spacing: 12) {
                    Text(pages[state.currentTutorialPage].title)
                        .font(.title.bold())
                        .foregroundColor(.outerSpace)
                        .multilineTextAlignment(.center)
                    
                    Text(pages[state.currentTutorialPage].subtitle)
                        .font(.body)
                        .foregroundColor(.cadetGray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                
                Spacer(minLength: 0)
                
                // Page Indicators
                PageIndicator(
                    currentPage: state.currentTutorialPage,
                    totalPages: state.totalTutorialPages
                )
                
                // Navigation Button
                Button(action: handleNavigation) {
                    Text(isLastPage ? "Get Started" : "Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.burntSienna)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(Color.dimGray.opacity(0.1))
            .animation(.smooth, value: state.currentTutorialPage)
        }
    }
    
    private var isLastPage: Bool {
        state.currentTutorialPage == pages.count - 1
    }
    
    private func handleNavigation() {
        if isLastPage {
            state.advance()
        } else {
            state.currentTutorialPage += 1
        }
    }
}

#Preview {
    TutorialView()
        .environmentObject(OnboardingState())
} 