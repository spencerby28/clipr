import AppwriteModels
import SwiftUI
import Foundation
import AVKit
import AVFoundation

struct VideoPlaceholderView: View {
    let video: AppwriteModels.File
    // Flag to indicate whether this cell is active (should play) or not.
    let isActive: Bool

    @StateObject private var videoPlayer = VideoPlayerManager()

    var body: some View {
        ZStack {
            if let url = AppwriteManager.shared.getVideoURL(fileId: video.id, bucketId: AppwriteManager.bucketId) {
                CustomVideoPlayerView(player: videoPlayer.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full size
                    .edgesIgnoringSafeArea(.all) // Fill the entire space
                    .onAppear {
                        print("Video view appeared for ID: \(video.id)")
                        videoPlayer.setVideo(url: url)
                        if isActive {
                            videoPlayer.play()
                        }
                    }
                    .onDisappear {
                        print("Video view disappeared for ID: \(video.id)")
                        videoPlayer.pause()
                    }
            } else {
                Color.black
                    .overlay(
                        Text("Unable to load video")
                            .foregroundColor(.white)
                    )
            }
            
            // Progress bar overlay
            VStack {
                Spacer()
                GeometryReader { geo in
                    let progressWidth = geo.size.width * CGFloat(videoPlayer.progress)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.5))
                        Capsule()
                            .fill(Color.red)
                            .frame(width: progressWidth)
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 16)
                }
                .frame(height: 4)
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                videoPlayer.play()
            } else {
                videoPlayer.pause()
            }
        }
    }
} 
