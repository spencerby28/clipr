import SwiftUI
import AVKit
import Kingfisher

struct VideoCell: View {
    let video: FeedViewModel.VideoWithMetadata
    let index: Int
    @ObservedObject var videoManager: VideoLoadingManager
    @State private var isPlaying = false
    @State private var isVideoLoaded = false
    @State private var isPulsing = false
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate the visible fraction of this cell.
            let frame = geometry.frame(in: .global)
            let screenHeight = UIScreen.main.bounds.height
            let visibleHeight = max(0, min(frame.maxY, screenHeight) - max(frame.minY, 0))
            let visibility = visibleHeight / geometry.size.height
            
          
            
            ZStack(alignment: .center) {
                // Show thumbnail while video is loading
                if !isVideoLoaded, let thumbnailURL = video.metadata.thumbnailURL {
            
                    ZStack(alignment: .bottom) {
                        KFImage(thumbnailURL)
                            .placeholder {
                                Color.black
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .edgesIgnoringSafeArea(.all)
                            
                        
                        // Pulsing overlay
                        Color.black.opacity(isPulsing ? 0.3 : 0.1)
                            .edgesIgnoringSafeArea(.all)
                            .animation(
                                Animation.easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true),
                                value: isPulsing
                            )
                            .onAppear {
                                // Only log initial appearance
                                print("🎥 Cell \(index): Appeared with thumbnail")
                                isPulsing = true
                            }
                            
                        // Video metadata overlay for thumbnail
                        if let user = video.metadata.users {
                            VideoMetadataView(
                                video: video.metadata,
                                user: user
                            )
                            .opacity(0.7)
                            .allowsHitTesting(true)
                        }
                    }
                    .frame(maxWidth: geometry.size.width, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                }
                
                if let url = video.url,
                   let player = videoManager.playerFor(index: index) {
                    ZStack(alignment: .bottom) {
                        CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                        
                        // Video metadata overlay for video
                        if let user = video.metadata.users {
                            VideoMetadataView(
                                video: video.metadata,
                                user: user
                            )
                            .opacity(isPlaying ? 1 : 0.7)
                            .animation(.easeInOut(duration: 0.3), value: isPlaying)
                            .allowsHitTesting(true)
                        }
                    }
                    .frame(maxWidth: geometry.size.width, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        print("🎥 Cell \(index): Player ready")
                        
                        // Set up looping for this player.
                        player.actionAtItemEnd = .none
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main) { _ in
                                player.seek(to: .zero)
                                if self.isPlaying {
                                    player.play()
                                }
                            }
                        
                        if visibility > 0.5 {
                            print("▶️ Cell \(index): Auto-playing (visibility: \(String(format: "%.2f", visibility)))")
                            player.play()
                            isPlaying = true
                        }
                        
                        // Observe when the video is ready to play
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemNewAccessLogEntry,
                            object: player.currentItem,
                            queue: .main) { _ in
                                if player.currentItem?.status == .readyToPlay {
                                    print("✅ Cell \(index): Video loaded")
                                    withAnimation {
                                        isVideoLoaded = true
                                        isPulsing = false
                                    }
                                }
                            }
                    }
                    .onDisappear {
                        print("🎥 Cell \(index): Disappeared")
                        NotificationCenter.default.removeObserver(
                            self,
                            name: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem
                        )
                        NotificationCenter.default.removeObserver(
                            self,
                            name: .AVPlayerItemNewAccessLogEntry,
                            object: player.currentItem
                        )
                        player.pause()
                        isPlaying = false
                        isVideoLoaded = false
                        isPulsing = false
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPlaying.toggle()
                        if isPlaying {
                            print("▶️ Cell \(index): Manual play")
                            player.play()
                        } else {
                            print("⏸️ Cell \(index): Manual pause")
                            player.pause()
                        }
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
            // Watch the visibility value and play/pause accordingly.
            .onChange(of: visibility) { newVisibility in
                if let url = video.url,
                   let player = videoManager.playerFor(index: index) {
                    if newVisibility > 0.5 && !isPlaying {
                        print("▶️ Cell \(index): Auto-playing on visibility change (\(String(format: "%.2f", newVisibility)))")
                        player.play()
                        isPlaying = true
                    } else if newVisibility <= 0.5 && isPlaying {
                        print("⏸️ Cell \(index): Auto-pausing on visibility change (\(String(format: "%.2f", newVisibility)))")
                        player.pause()
                        isPlaying = false
                    }
                }
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
        
        controller.allowsVideoFrameAnalysis = false
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
