//
//  ApertureView.swift
//  clipr
//
//  Created by Spencer Byrne on 2/10/25.
//

import SwiftUI

struct CliprShape: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let bounds = CGRect(x: 0, y: 0, width: 839, height: 839)
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: (rect.width - bounds.width * scale) / 2,
                                           y: (rect.height - bounds.height * scale) / 2))
        
        let shape = UIBezierPath()
        
        // Outer circle
        shape.move(to: CGPoint(x: 419.5, y: 839))
        shape.addCurve(to: CGPoint(x: 839, y: 419.5), controlPoint1: CGPoint(x: 651.18, y: 839), controlPoint2: CGPoint(x: 839, y: 651.18))
        shape.addCurve(to: CGPoint(x: 419.5, y: 0), controlPoint1: CGPoint(x: 839, y: 187.82), controlPoint2: CGPoint(x: 651.18, y: 0))
        shape.addCurve(to: CGPoint(x: 0, y: 419.5), controlPoint1: CGPoint(x: 187.82, y: 0), controlPoint2: CGPoint(x: 0, y: 187.82))
        shape.addCurve(to: CGPoint(x: 419.5, y: 839), controlPoint1: CGPoint(x: 0, y: 651.18), controlPoint2: CGPoint(x: 187.82, y: 839))
        shape.close()
        
        // Blade paths
        let bladeProgress = progress * 2 - 1 // Start blades after circle is formed
        if bladeProgress > 0 {
            // Right blade
            shape.move(to: CGPoint(x: 387.7, y: 610.18))
            shape.addLine(to: CGPoint(x: 476.27, y: 757.79))
            shape.addCurve(to: CGPoint(x: 704.62, y: 610.18), controlPoint1: CGPoint(x: 571.29, y: 741.96), controlPoint2: CGPoint(x: 653.09, y: 687.07))
            shape.addLine(to: CGPoint(x: 387.7, y: 610.18))
            shape.close()
            
            // Bottom left blade
            shape.move(to: CGPoint(x: 224.11, y: 485.78))
            shape.addLine(to: CGPoint(x: 389.34, y: 761.16))
            shape.addCurve(to: CGPoint(x: 137.82, y: 615.21), controlPoint1: CGPoint(x: 285.19, y: 752.08), controlPoint2: CGPoint(x: 194.38, y: 696.46))
            shape.addLine(to: CGPoint(x: 224.11, y: 485.78))
            shape.close()
            
            // Left blade
            shape.move(to: CGPoint(x: 252.9, y: 305.09))
            shape.addLine(to: CGPoint(x: 96.08, y: 305.09))
            shape.addCurve(to: CGPoint(x: 76.53, y: 419.5), controlPoint1: CGPoint(x: 83.42, y: 340.87), controlPoint2: CGPoint(x: 76.53, y: 379.38))
            shape.addCurve(to: CGPoint(x: 97.58, y: 538.07), controlPoint1: CGPoint(x: 76.53, y: 461.18), controlPoint2: CGPoint(x: 83.97, y: 501.12))
            shape.addLine(to: CGPoint(x: 252.9, y: 305.09))
            shape.close()
            
            // Top right blade
            shape.move(to: CGPoint(x: 742.92, y: 533.91))
            shape.addLine(to: CGPoint(x: 584.03, y: 533.91))
            shape.addLine(to: CGPoint(x: 737.53, y: 290.87))
            shape.addCurve(to: CGPoint(x: 762.47, y: 419.5), controlPoint1: CGPoint(x: 753.61, y: 330.59), controlPoint2: CGPoint(x: 762.47, y: 374.01))
            shape.addCurve(to: CGPoint(x: 742.92, y: 533.91), controlPoint1: CGPoint(x: 762.47, y: 459.62), controlPoint2: CGPoint(x: 755.58, y: 498.13))
            shape.close()
            
            // Top blade
            shape.move(to: CGPoint(x: 451.3, y: 228.82))
            shape.addLine(to: CGPoint(x: 134.38, y: 228.82))
            shape.addCurve(to: CGPoint(x: 362.73, y: 81.21), controlPoint1: CGPoint(x: 185.91, y: 151.93), controlPoint2: CGPoint(x: 267.71, y: 97.04))
            shape.addLine(to: CGPoint(x: 451.3, y: 228.82))
            shape.close()
            
            // Top left blade
            shape.move(to: CGPoint(x: 449.66, y: 77.84))
            shape.addLine(to: CGPoint(x: 611.51, y: 347.58))
            shape.addLine(to: CGPoint(x: 695.06, y: 215.28))
            shape.addCurve(to: CGPoint(x: 449.66, y: 77.84), controlPoint1: CGPoint(x: 638.19, y: 138.67), controlPoint2: CGPoint(x: 550.13, y: 86.59))
            shape.close()
            
            // Center hexagon
            shape.move(to: CGPoint(x: 273.79, y: 419.5))
            shape.addLine(to: CGPoint(x: 345.29, y: 305.09))
            shape.addLine(to: CGPoint(x: 493.71, y: 305.09))
            shape.addLine(to: CGPoint(x: 565.21, y: 419.5))
            shape.addLine(to: CGPoint(x: 493.71, y: 533.91))
            shape.addLine(to: CGPoint(x: 345.29, y: 533.91))
            shape.addLine(to: CGPoint(x: 273.79, y: 419.5))
            shape.close()
        }
        
        return Path(shape.cgPath).applying(transform)
    }
}

struct ApertureView: View {
    @Binding var isOpening: Bool
    let completion: (() -> Void)?
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        CliprShape(progress: progress)
          //  .fill(Color(hex: "DD6E42"))
            .aspectRatio(1, contentMode: .fit)
            .onChange(of: isOpening) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    progress = newValue ? 1.0 : 0.0
                }
                
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        completion?()
                    }
                }
            }
    }
}



// MARK: - Preview
struct ApertureView_Previews: View {
    @State private var isOpening: Bool = false
    
    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ApertureView(isOpening: $isOpening, completion: {
                    
                })
                    .frame(width: 200, height: 200)
                
                Button(action: {
                    isOpening.toggle()
                }) {
                    Text(isOpening ? "Close Aperture" : "Open Aperture")
                        .padding()
                        .background(Color(hex: "DD6E42"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
}

#Preview {
    ApertureView_Previews()
}
