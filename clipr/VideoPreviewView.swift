import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    let onRetake: () -> Void
    let onSend: () -> Void
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video preview container with rounded corners.
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width - 32,
                               height: (geometry.size.width - 32) * (16/9))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    // Fallback view in case the player isn't yet loaded.
                    Color.black
                        .frame(width: geometry.size.width - 32,
                               height: (geometry.size.width - 32) * (16/9))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Overlay: Action controls at the bottom.
                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        Button(action: {
                            onRetake()
                        }) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 24))
                                Text("Retake")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            onSend()
                        }) {
                            VStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 30))
                                Text("Send")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            // Center the preview container within the full screen.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            // Initialize and start the video player.
            player = AVPlayer(url: videoURL)
            player?.play()
            
            // Loop the video playback.
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            NotificationCenter.default.removeObserver(self)
        }
    }
} 