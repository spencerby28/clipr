import SwiftUI
import AVKit

struct SimpleVideoView: View {
    let url: URL
    let index: Int
    @ObservedObject var videoManager: VideoLoadingManager
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let player = videoManager.playerFor(index: index) {
                CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isPlaying.toggle()
                        if isPlaying {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
                
                // Debug controls overlay
                VStack {
                    Spacer()
                    HStack {
                        Button(isPlaying ? "Pause" : "Play") {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            isPlaying.toggle()
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            videoManager.preloadVideosAround(index: index)
            if let player = videoManager.playerFor(index: index) {
                player.play()
                isPlaying = true
            }
        }
        .onDisappear {
            if let player = videoManager.playerFor(index: index) {
                player.pause()
                isPlaying = false
            }
        }
        .statusBar(hidden: true)
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