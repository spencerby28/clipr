import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let progress: Double
    let action: () -> Void
    
    private let cornerRadius: CGFloat = 24
    private let borderWidth: CGFloat = 3
    private let buttonSize: CGFloat = 70
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !isRecording {
                    // Only show record button when not recording
                    VStack {
                        Spacer()
                        Button(action: action) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)
                    }
                } else {
                    // Recording border - positioned outside the preview
                    RecordingBorder(
                        progress: progress,
                        cornerRadius: cornerRadius
                    )
                    .stroke(Color.red, lineWidth: borderWidth)
                    .padding(borderWidth/2)  // Adjust for border width
                    
                    // Processing overlay (shows when progress > 1.0)
                    if progress >= 1.0 {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.3),
                                        Color.black.opacity(0.7)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(borderWidth/2)  // Match border padding
                            .transition(.opacity)
                    }
                }
            }
        }
    }
}

struct RecordingBorder: Shape {
    var progress: Double
    var cornerRadius: CGFloat
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topSegmentEnd = 0.15
        let firstHalfEnd = 0.5  // Progress at 3-second mark
        let sideSegmentsEnd = 1.0
        
        // Start from top middle
        let startPoint = CGPoint(x: rect.midX, y: 0)
        path.move(to: startPoint)
        
        // Draw top segments with rounded corners
        let topProgress = min(progress / topSegmentEnd, 1.0)
        
        // Top right with corner
        if topProgress > 0 {
            let rightEnd = rect.midX + (rect.width/2 - cornerRadius) * topProgress
            path.addLine(to: CGPoint(x: rightEnd, y: 0))
            
            if topProgress == 1.0 {
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            }
        }
        
        // Top left with corner
        path.move(to: startPoint)
        if topProgress > 0 {
            let leftEnd = rect.midX - (rect.width/2 - cornerRadius) * topProgress
            path.addLine(to: CGPoint(x: leftEnd, y: 0))
            
            if topProgress == 1.0 {
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(180),
                    clockwise: true
                )
            }
        }
        
        if progress > topSegmentEnd {
            // Calculate progress for sides
            let adjustedProgress = progress > firstHalfEnd 
                ? ((progress - firstHalfEnd) / (sideSegmentsEnd - firstHalfEnd)) * 0.5 + 0.5  // Second half
                : (progress - topSegmentEnd) / (firstHalfEnd - topSegmentEnd) * 0.5  // First half
            
            let sideHeight = (rect.height - cornerRadius * 2) * adjustedProgress
            
            // Right side
            path.move(to: CGPoint(x: rect.maxX, y: cornerRadius))
            path.addLine(to: CGPoint(x: rect.maxX, y: cornerRadius + sideHeight))
            
            // Left side
            path.move(to: CGPoint(x: 0, y: cornerRadius))
            path.addLine(to: CGPoint(x: 0, y: cornerRadius + sideHeight))
            
            // Add bottom corners and line if we're at the end
            if progress >= 1.0 {
                // Bottom right corner
                path.move(to: CGPoint(x: rect.maxX, y: rect.height - cornerRadius))
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: rect.height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )
                
                // Bottom line
                path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
                
                // Bottom left corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: rect.height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )
            }
        }
        
        return path
    }
} 