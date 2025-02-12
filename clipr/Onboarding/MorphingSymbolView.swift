//
//  MorphingSymbolView.swift
//  Walkthrough+Morphing
//
//  Created by Balaji Venkatesh on 28/07/24.
//

import SwiftUI

/// Custom Symbol Morphing View
struct MorphingSymbolView: View {
    var symbol: String
    var config: Config
    /// View Properties
    @State private var trigger: Bool = false
    @State private var displayingSymbol: String = ""
    @State private var nextSymbol: String = ""
    
    var body: some View {
        Canvas { ctx, size in
            ctx.addFilter(.alphaThreshold(min: 0.4, color: config.foregroundColor))
            
            if let renderedImage = ctx.resolveSymbol(id: 0) {
                ctx.draw(renderedImage, at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        } symbols: {
            ImageView()
                .tag(0)
        }
        .frame(width: config.frame.width, height: config.frame.height)
        .onChange(of: symbol) { oldValue, newValue in
            trigger.toggle()
            nextSymbol = newValue
        }
        .task {
            guard displayingSymbol == "" else { return }
            displayingSymbol = symbol
        }
    }
    
    @ViewBuilder
    func ImageView() -> some View {
        KeyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { radius in
            Group {
                if displayingSymbol == "" ? symbol == "clipr" : displayingSymbol == "clipr" {
                    // For custom clipr image
                    Image("clipr-trans")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .blur(radius: radius)
                        .frame(width: config.frame.width, height: config.frame.height)
                } else {
                    // For SF Symbols
                    Image(systemName: displayingSymbol == "" ? symbol : displayingSymbol)
                        .font(config.font)
                        .blur(radius: radius)
                        .frame(width: config.frame.width, height: config.frame.height)
                }
            }
            .onChange(of: radius) { oldValue, newValue in
                if newValue.rounded() == config.radius {
                    /// Animating Symbol Change
                    withAnimation(config.symbolAnimation) {
                        displayingSymbol = nextSymbol
                    }
                }
            }
        } keyframes: { _ in
            CubicKeyframe(config.radius, duration: config.keyFrameDuration)
            CubicKeyframe(0, duration: config.keyFrameDuration)
        }
    }
    
    struct Config {
        var font: Font
        var frame: CGSize
        var radius: CGFloat
        var foregroundColor: Color
        var keyFrameDuration: CGFloat = 0.4
        var symbolAnimation: Animation = .smooth(duration: 0.3, extraBounce: 0)
    }
}

#Preview {
    MorphingSymbolView(symbol: "clipr", config: .init(font: .system(size: 100, weight: .bold), frame: CGSize(width: 250, height: 200), radius: 15, foregroundColor: .black))
}
