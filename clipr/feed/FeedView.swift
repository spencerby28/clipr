import SwiftUI
import Appwrite
import AVKit

struct FeedView: View {
    @StateObject private var videoManager: VideoLoadingManager
    @StateObject private var viewModel: FeedViewModel
    @State private var currentIndex: Int? = 0  // Make optional
    
    init() {
        let manager = VideoLoadingManager()
        _videoManager = StateObject(wrappedValue: manager)
        _viewModel = StateObject(wrappedValue: FeedViewModel(videoManager: manager))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                        if let url = AppwriteManager.shared.getVideoURL(fileId: video.id, bucketId: AppwriteManager.bucketId) {
                            SimpleVideoView(url: url, index: index, videoManager: videoManager)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                        } else {
                            Text("Failed to load video")
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .onChange(of: currentIndex) { oldValue, newValue in
                // Pause all videos except the current one
                if let index = newValue {
                    videoManager.pauseAllExcept(index: index)
                }
            }
            .ignoresSafeArea()
            .statusBar(hidden: true)
            .onAppear {
                Task {
                    await viewModel.loadVideos()
                }
            }
        }
        .ignoresSafeArea(edges: .all)
    }
}

class FeedViewModel: ObservableObject {
    @Published var videos: [AppwriteModels.File] = []
    private let appwrite = AppwriteManager.shared
    private let videoManager: VideoLoadingManager
    
    init(videoManager: VideoLoadingManager) {
        self.videoManager = videoManager
    }
    
    @MainActor
    func loadVideos() async {
        do {
            self.videos = try await appwrite.listVideos()
            // Convert to URLs
            let urls = videos.compactMap { video in
                AppwriteManager.shared.getVideoURL(fileId: video.id, bucketId: AppwriteManager.bucketId)
            }
            videoManager.setVideos(urls)
        } catch {
            print("Error loading videos: \(error)")
        }
    }
}

#Preview {
    FeedView()
}
