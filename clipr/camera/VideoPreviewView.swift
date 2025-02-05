import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    let onRetake: () -> Void
    let onSend: (@escaping (Double) -> Void) async -> Void
    
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var uploadProgress: CGFloat = 0
    @State private var animationProgress: CGFloat = 0
    @State private var isUploading = false
    @State private var uploadComplete = false
    @State private var borderOpacity: Double = 1.0
    @State private var isPlaying = true
    @State private var isPulsing = false
    
    // Constants for animation
    private let standardAnimationDuration: Double = 4.5
    private let pauseThreshold: CGFloat = 0.85
    private let pulseOpacity: Double = 0.6
    private let cornerRadius: CGFloat = 24
    private let borderPadding: CGFloat = 3  // Border offset from video frame
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .padding(borderPadding) // Add padding for the border
                        .overlay(
                            ZStack {
                                // Progress border
                                ProgressBorder(
                                    progress: animationProgress,
                                    cornerRadius: cornerRadius,
                                    rect: CGRect(
                                        x: 0,
                                        y: 0,
                                        width: geometry.size.width - (borderPadding * 2),
                                        height: (geometry.size.width - (borderPadding * 2)) * (16/9)
                                    )
                                )
                                .stroke(Color.white, lineWidth: 3)
                                .opacity(isPulsing ? pulseOpacity : borderOpacity)
                                .animation(isPulsing ? 
                                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                                    .default, 
                                 value: isPulsing ? pulseOpacity : borderOpacity)
                            }
                            .padding(borderPadding)
                        )
                }
                
                if !isLoading {
                    VStack {
                        Spacer()
                        HStack(spacing: 40) {
                            Button(action: onRetake) {
                                VStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24))
                                    Text("Retake")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                            }
                            .disabled(isUploading)
                            
                            Button(action: {
                                startUploadProcess()
                            }) {
                                VStack {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 24))
                                    Text("Send")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                            }
                            .disabled(isUploading)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            setupVideoPlayback()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: uploadProgress) { _, progress in
            if progress >= 1.0 {
                // Upload complete, stop pulsing
                isPulsing = false
                
                // Quickly complete the border
                withAnimation(.easeOut(duration: 0.2)) {
                    animationProgress = 1.0
                }
                
                // Wait for border completion before fading
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        borderOpacity = 0
                    }
                }
            }
        }
        .onChange(of: animationProgress) { _, progress in
            if progress >= pauseThreshold && !uploadComplete {
                isPulsing = true
            }
        }
    }
    
    private func setupVideoPlayback() {
        let player = AVPlayer(url: videoURL)
        self.player = player
        player.play()
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func startUploadProcess() {
        isLoading = true
        isUploading = true
        
        // Start the continuous border animation
        withAnimation(.linear(duration: standardAnimationDuration)) {
            animationProgress = pauseThreshold
        }
        
        Task {
            await onSend { progress in
                uploadProgress = progress
                if progress >= 1.0 {
                    uploadComplete = true
                }
            }
        }
    }
}

struct ProgressBorder: Shape {
    var progress: CGFloat
    var cornerRadius: CGFloat
    var rect: CGRect
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topSegmentEnd = 0.15
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
            let sideProgress = min((progress - topSegmentEnd) / (sideSegmentsEnd - topSegmentEnd), 1.0)
            let sideHeight = (rect.height - cornerRadius * 2) * sideProgress
            
            // Right side
            path.move(to: CGPoint(x: rect.maxX, y: cornerRadius))
            path.addLine(to: CGPoint(x: rect.maxX, y: cornerRadius + sideHeight))
            
            // Left side
            path.move(to: CGPoint(x: 0, y: cornerRadius))
            path.addLine(to: CGPoint(x: 0, y: cornerRadius + sideHeight))
        }
        
        return path
    }
} 
