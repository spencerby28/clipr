
import SwiftUI
import Foundation

struct PageIndicator: View {
    var currentPage: OnboardingPage
    var activeColor: Color = .burntSienna
    var inactiveColor: Color = .burntSienna.opacity(0.4)
    var activeDotWidth: CGFloat = 25
    var dotHeight: CGFloat = 8
    var spacing: CGFloat = 6
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                Capsule()
                    .fill(currentPage == page ? activeColor : inactiveColor)
                    .frame(width: currentPage == page ? activeDotWidth : dotHeight, 
                           height: dotHeight)
            }
        }
        .animation(.smooth(duration: 0.5), value: currentPage)
        .padding(.bottom, 12)
    }
} 
