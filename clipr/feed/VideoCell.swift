
import SwiftUI
import AVKit

struct VideoCell: View {
    let video: FeedViewModel.VideoWithMetadata
    let index: Int
    @ObservedObject var videoManager: VideoLoadingManager
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let url = video.url,
               let player = videoManager.playerFor(index: index) {
                CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        configurePlayer(player)
                    }
                    .onDisappear {
                        cleanupPlayer(player)
                    }
                    .onTapGesture {
                        togglePlayback(player)
                    }
                
                // Video metadata overlay
                if let user = video.metadata.users {
                    VideoMetadataView(
                        video: video.metadata,
                        user: user
                    )
                    .opacity(isPlaying ? 1 : 0.7)
                    .animation(.easeInOut, value: isPlaying)
                }
            }
        }
    }
    
    private func configurePlayer(_ player: AVPlayer) {
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
        player.play()
        isPlaying = true
    }
    
    private func cleanupPlayer(_ player: AVPlayer) {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        player.pause()
        isPlaying = false
    }
    
    private func togglePlayback(_ player: AVPlayer) {
        isPlaying.toggle()
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        // Remove the black background
        controller.view.backgroundColor = .clear
        
        // Make it fill the whole screen
        if let playerLayer = controller.view.layer as? AVPlayerLayer {
            playerLayer.frame = UIScreen.main.bounds
        }
        
        // Hide status bar
        controller.setNeedsStatusBarAppearanceUpdate()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
}

// Add status bar hiding support for AVPlayerViewController
extension AVPlayerViewController {
    open override var prefersStatusBarHidden: Bool {
        return true
    }
}
