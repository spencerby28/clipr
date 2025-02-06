import SwiftUI
import AVKit

struct VideoCell: View {
    let video: FeedViewModel.VideoWithMetadata
    let index: Int
    @ObservedObject var videoManager: VideoLoadingManager
    @State private var isPlaying = false
    
    var body: some View {
        ZStack(alignment: .center) {
            if let url = video.url,
               let player = videoManager.playerFor(index: index) {
                CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        // Configure player for looping
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
                    .onDisappear {
                        NotificationCenter.default.removeObserver(
                            self,
                            name: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem
                        )
                        player.pause()
                        isPlaying = false
                    }
                    .contentShape(Rectangle())  // Make the whole area tappable
                    .onTapGesture {
                        isPlaying.toggle()
                        if isPlaying {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
                
                // Video metadata overlay
                if let user = video.metadata.users {
                    VideoMetadataView(
                        video: video.metadata,
                        user: user
                    )
                    .opacity(isPlaying ? 1 : 0.7)
                    .animation(.easeInOut(duration: 0.3), value: isPlaying)
                    .allowsHitTesting(true)  // Enable interaction with metadata view
                }
            } else {
                Color.black
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        Text("Unable to load video")
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
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
        
        // Configure the view to fill its container
        controller.view.frame = UIScreen.main.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Make the player layer fill the whole screen
        if let playerLayer = controller.view.layer as? AVPlayerLayer {
            playerLayer.frame = controller.view.bounds
            playerLayer.videoGravity = .resizeAspectFill
        }
        
        // Disable text interaction and system gestures
        controller.view.isUserInteractionEnabled = true
        for subview in controller.view.subviews {
            subview.isUserInteractionEnabled = false
        }
        
        // Add a clear tap gesture recognizer to prevent system gestures
        let tapGesture = UITapGestureRecognizer()
        tapGesture.cancelsTouchesInView = false
        controller.view.addGestureRecognizer(tapGesture)
        
        // Hide status bar
        controller.setNeedsStatusBarAppearanceUpdate()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update the view's frame to match its container
        uiViewController.view.frame = uiViewController.view.superview?.bounds ?? UIScreen.main.bounds
        
        // Update the player layer to match the view's bounds
        if let playerLayer = uiViewController.view.layer as? AVPlayerLayer {
            playerLayer.frame = uiViewController.view.bounds
            playerLayer.videoGravity = .resizeAspectFill
        }
        
        // Ensure text interaction remains disabled when view updates
        for subview in uiViewController.view.subviews {
            subview.isUserInteractionEnabled = false
        }
    }
}

// Add status bar hiding support for AVPlayerViewController
extension AVPlayerViewController {
    open override var prefersStatusBarHidden: Bool {
        return true
    }
    
    open override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}
