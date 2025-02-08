import SwiftUI
import AVKit

struct VideoPreviewView: View {
    @EnvironmentObject private var navigationState: NavigationState
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
    @State private var showError = false
    @State private var showPrivacyOptions = false
    @State private var selectedPrivacy: PrivacyOption = .world
    
    // Constants for animation
    private let standardAnimationDuration: Double = 4.5
    private let pauseThreshold: CGFloat = 0.85
    private let pulseOpacity: Double = 0.6
    private let cornerRadius: CGFloat = 24
    private let borderPadding: CGFloat = 3  // Border offset from video frame
    
    enum PrivacyOption {
        case world, friends
        
        var icon: String {
            switch self {
            case .world: return "globe"
            case .friends: return "person.2.fill"
            }
        }
        
        var text: String {
            switch self {
            case .world: return "Everyone"
            case .friends: return "Friends"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .padding(borderPadding)
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
                                .opacity(uploadComplete && isPulsing ? pulseOpacity : borderOpacity)
                                .animation(uploadComplete && isPulsing ? 
                                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                                    .default, 
                                 value: isPulsing ? pulseOpacity : borderOpacity)
                            }
                            .padding(borderPadding)
                        )
                }
                
                // Privacy selector
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showPrivacyOptions.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: selectedPrivacy.icon)
                                    .font(.system(size: 20))
                                Text(selectedPrivacy.text)
                                    .font(.system(size: 12))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(.thinMaterial)
                                    .preferredColorScheme(.dark)
                                    .opacity(0.7)
                            }
                        }
                        .padding(.top, 40)
                        .padding(.trailing, 16)
                    }
                    
                    if showPrivacyOptions {
                        VStack(spacing: 8) {
                            ForEach([PrivacyOption.world, PrivacyOption.friends], id: \.text) { option in
                                Button(action: {
                                    selectedPrivacy = option
                                    showPrivacyOptions = false
                                }) {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.text)
                                        Spacer()
                                        if selectedPrivacy == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.thinMaterial)
                                .preferredColorScheme(.dark)
                        }
                        .padding(.horizontal, 16)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                
                if showError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                        
                        Text("Uh oh, an error occurred")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: onRetake) {
                            Text("Try Again")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                } else if !isLoading {
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            Button(action: onRetake) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 20))
                                    Text("Retake")
                                        .font(.system(size: 12))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 1, height: 24)
                                .padding(.horizontal, 8)
                            
                            Button(action: {
                                startUploadProcess()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 20))
                                    Text("Send")
                                        .font(.system(size: 12))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                        .background {
                            Capsule()
                                .fill(.thinMaterial)
                                .preferredColorScheme(.dark)
                                .opacity(0.7)
                        }
                        .disabled(isUploading)
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
                uploadComplete = true
                isPulsing = true
                
                // Quickly complete the border
                withAnimation(.easeOut(duration: 0.2)) {
                    animationProgress = 1.0
                }
                
                // Wait for border completion before fading and navigating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        borderOpacity = 0
                    }
                    // Navigate back to feed after successful upload
                    navigationState.navigateTo(.feed)
                }
            } else if progress < 0 {  // Error case
                withAnimation {
                    showError = true
                }
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
