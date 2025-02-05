import SwiftUI
import Appwrite
import AVKit
import AppwriteModels

struct FeedView: View {
    @StateObject private var videoManager: VideoLoadingManager
    @StateObject private var viewModel: FeedViewModel
    @State private var currentIndex: Int? = 0
    
    init() {
        let manager = VideoLoadingManager()
        _videoManager = StateObject(wrappedValue: manager)
        _viewModel = StateObject(wrappedValue: FeedViewModel(videoManager: manager))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch viewModel.loadingState {
                case .idle, .loading where viewModel.videos.isEmpty:
                    LoadingView()
                case .error(let message):
                    ErrorView(message: message) {
                        Task {
                            await viewModel.loadVideos(refresh: true)
                        }
                    }
                case .loading, .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                VideoCell(video: video, index: index, videoManager: videoManager)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .id(index)
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentIndex)
                    .onChange(of: currentIndex) { oldValue, newValue in
                        handleScrollPositionChange(oldValue: oldValue, newValue: newValue)
                    }
                    .refreshable {
                        await viewModel.loadVideos(refresh: true)
                    }
                }
            }
            .ignoresSafeArea()
            .statusBar(hidden: true)
            .task {
                await viewModel.loadVideos()
            }
        }
    }
    
    private func handleScrollPositionChange(oldValue: Int?, newValue: Int?) {
        guard let index = newValue else { return }
        
        // Pause all videos except current
        videoManager.pauseAllExcept(index: index)
        
        // Preload adjacent videos
        videoManager.preloadVideosAround(index: index)
        
        // Load more content if needed
        if index >= viewModel.videos.count - 3 {
            Task {
                await viewModel.loadVideos()
            }
        }
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading videos...")
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error loading videos")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
}

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
                    .onTapGesture {
                        isPlaying.toggle()
                        if isPlaying {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
                
                // Video metadata overlay
                VideoMetadataView(video: video.metadata, user: video.creator ?? AppwriteManager.shared.currentUser!)
                    .opacity(isPlaying ? 1 : 0.7)
                    .animation(.easeInOut, value: isPlaying)
            } else {
                Color.black
                    .overlay(
                        Text("Unable to load video")
                            .foregroundColor(.white)
                    )
            }
        }
    }
}



#Preview {
    FeedView()
}
