import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    let onRetake: () -> Void
    let onSend: () -> Void
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
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
                    
                    Button(action: onSend) {
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
        .onAppear {
            // Initialize player with video URL
            player = AVPlayer(url: videoURL)
            player?.play()
            
            // Loop video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main) { _ in
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