import SwiftUI

struct OnboardingSymbolView: View {
    let page: OnboardingPage
    
    var body: some View {
        MorphingSymbolView(
            symbol: page.rawValue,
            config: .init(
                font: .system(size: page.symbolSize, weight: page.symbolWeight),
                frame: .init(width: 200, height: 160),
                radius: 25,
                foregroundColor: page.symbolColor,
                keyFrameDuration: page.animationDuration
            )
        )
    }
} 
