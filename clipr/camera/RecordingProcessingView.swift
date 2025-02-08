//
//  RecordingProcessingView.swift
//  clipr
//
//  Created by Spencer Byrne on 2/7/25.
//

import Foundation
import SwiftUI

struct RecordingProcessingView: View {
    @State private var gradientRotation = 0.0
    @State private var pulseScale = 1.0
    
    private let cornerRadius: CGFloat
    private let gradient = AngularGradient(
        gradient: Gradient(colors: [
            Color(red: 0.91, green: 0.27, blue: 0.23),   // Red
            Color(red: 0.98, green: 0.57, blue: 0.47),   // Coral
            Color(red: 1.0, green: 0.8, blue: 0.4),      // Warm Yellow
            Color(red: 0.98, green: 0.57, blue: 0.47),   // Coral
            Color(red: 0.91, green: 0.27, blue: 0.23),   // Red
        ]),
        center: .center
    )
    
    init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            let maxDimension = max(geometry.size.width, geometry.size.height)
            let scale = (maxDimension / min(geometry.size.width, geometry.size.height)) * 2.5
            
            ZStack {
                // Base color
                Color.black
                
                // Animated gradient background
                Circle()
                    .fill(gradient)
                    .rotationEffect(.degrees(gradientRotation))
                    .scaleEffect(scale)
                    .blur(radius: 30)
                
                // Darkening overlay
                Color.black.opacity(0.15)
                
                // Content overlay
                VStack(spacing: 24) {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(pulseScale)
                    
                    Text("Creating your clip...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(0.9)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                // Continuous rotation animation
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    gradientRotation = 360
                }
                
                // Pulsing animation
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    pulseScale = 1.2
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        RecordingProcessingView()
            .frame(width: 300, height: 500)
            .padding()
    }
}
