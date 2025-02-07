import SwiftUI
import Appwrite
import AVKit

struct FeedView: View {
    @StateObject private var videoManager: VideoLoadingManager
    @StateObject private var viewModel: FeedViewModel
    @State private var currentIndex: Int? = 0
    @State private var selectedFeed: FeedType = .friends
    @State private var isFeedExpanded: Bool = false
    @State private var showSettingsSheet = false
    @State private var showProfileSheet = false
    
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
                    ZStack {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                    VideoCell(video: video, index: index, videoManager: videoManager)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .edgesIgnoringSafeArea(.all)
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
                        .edgesIgnoringSafeArea(.all)
                        
                        // App title overlay
                        VStack(spacing: 0) {
                            if isFeedExpanded {
                                FeedActionItems(showSettingsSheet: $showSettingsSheet, showProfileSheet: $showProfileSheet, isExpanded: $isFeedExpanded)
                                    .ignoresSafeArea()
                            }
                            
                            VStack(spacing: 16) {
                                Text("clipr")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                FeedSelectorBadge(selectedFeed: $selectedFeed, isExpanded: $isFeedExpanded)
                            }
                            .padding(.top, isFeedExpanded ? -2 : 56)
                            
                            Spacer()
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                FriendSheet(isPresented: $showSettingsSheet)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileSheet(isPresented: $showProfileSheet)    
            }
            .onChange(of: showSettingsSheet) { _, isPresented in
                if isPresented, let currentIndex {
                    videoManager.pauseAllExcept(index: -1) // Pause all videos
                }
            }
            .onChange(of: showProfileSheet) { _, isPresented in
                if isPresented, let currentIndex {
                    videoManager.pauseAllExcept(index: -1) // Pause all videos
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .ignoresSafeArea(edges: .all)
            .statusBar(hidden: true)
            .task {
                await viewModel.loadVideos()
            }
        }
        .edgesIgnoringSafeArea(.all)
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

class FeedViewModel: ObservableObject {
    @Published var videos: [VideoWithMetadata] = []
    @Published var loadingState: LoadingState = .idle
    @Published var currentPage: Int = 1
    private let pageSize = 10
    private var hasMoreContent = true
    private var isLoadingMore = false
    private let videoManager: VideoLoadingManager
    
    init(videoManager: VideoLoadingManager) {
        self.videoManager = videoManager
    }
    
    struct VideoWithMetadata: Identifiable {
        let id: String
        let metadata: Video  // This already contains all we need
        var url: URL? {
            guard let videoId = metadata.videoId else { return nil }
            return AppwriteManager.shared.getVideoURL(
                fileId: videoId, 
                bucketId: AppwriteManager.bucketId
            )
        }
    }
    
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
        
        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    @MainActor
    func loadVideos(refresh: Bool = false) async {
        print("DEBUG: loadVideos called with refresh = \(refresh). Current page = \(currentPage).")

        if refresh {
            currentPage = 1
            videos = []
            hasMoreContent = true
            print("DEBUG: Refreshing. Resetting page to 1 and clearing videos.")
        }
        
        guard hasMoreContent && !isLoadingMore else {
            print("DEBUG: hasMoreContent = \(hasMoreContent), isLoadingMore = \(isLoadingMore). Aborting load.")
            return
        }
        
        isLoadingMore = true
        
        if videos.isEmpty {
            loadingState = .loading
            print("DEBUG: videos array is empty. Setting loading state to .loading.")
        }
        
        do {
            print("DEBUG: About to call listVideosWithMetadata. Limit = \(pageSize), offset = \((currentPage - 1) * pageSize)")
            let newVideos = try await AppwriteManager.shared.listVideosWithMetadata(
                limit: pageSize,
                offset: (currentPage - 1) * pageSize
            )
            
            print("DEBUG: listVideosWithMetadata returned \(newVideos.count) video(s).")
            
            // Log each video's metadata
            for (index, video) in newVideos.enumerated() {
                print("DEBUG: Video \(index) - Full object: \(String(describing: video))")
                print("DEBUG: Video \(index) - ID: \(video.id)")
                print("DEBUG: Video \(index) - VideoId: \(String(describing: video.videoId))")
                print("DEBUG: Video \(index) - Users: \(String(describing: video.users))")
                print("DEBUG: Video \(index) - Caption: \(String(describing: video.caption))")
            }
            
            let videoWithMetadata = newVideos.map { video in
                let metadata = VideoWithMetadata(
                    id: video.id,
                    metadata: video
                )
                print("DEBUG: Created VideoWithMetadata - ID: \(metadata.id), URL: \(String(describing: metadata.url))")
                return metadata
            }
            
            await MainActor.run {
                if refresh {
                    self.videos = videoWithMetadata
                } else {
                    self.videos.append(contentsOf: videoWithMetadata)
                }
                
                print("DEBUG: Now have \(self.videos.count) total videos stored in FeedViewModel.")

                self.currentPage += 1
                self.hasMoreContent = videoWithMetadata.count == pageSize
                self.loadingState = .loaded
                self.isLoadingMore = false
                
                // Preload video URLs
                let urls = videoWithMetadata.compactMap { $0.url }
                print("DEBUG: Preloading video URLs. Found \(urls.count) valid URLs.")
                print("DEBUG: URLs to preload: \(urls)")
                self.videoManager.setVideos(urls)
            }
        } catch {
            await MainActor.run {
                self.loadingState = .error(error.localizedDescription)
                self.isLoadingMore = false
            }
            print("ERROR: Failed to load videos: \(error.localizedDescription)")
        }
    }
}

struct FeedView_Previews: View {
    @State private var isExpanded: Bool = true
    @State private var showSettingsSheet = false
    @State private var showProfileSheet = false
    @State private var selectedFeed: FeedType = .friends
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.blue // Simple blue background
                
                VStack(spacing: 0) {
                    if isExpanded {
                        FeedActionItems(showSettingsSheet: $showSettingsSheet, showProfileSheet: $showProfileSheet, isExpanded: $isExpanded)
                            .ignoresSafeArea()
                    }
                    
                    VStack(spacing: 16) {
                        Text("clipr")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        FeedSelectorBadge(selectedFeed: $selectedFeed, isExpanded: $isExpanded)
                            .onTapGesture {
                                if selectedFeed == .friends {
                                    showSettingsSheet = true
                                }
                            }
                    }
                    .padding(.top, isExpanded ? -2 : 56)
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                FriendSheet(isPresented: $showSettingsSheet)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileSheet(isPresented: $showProfileSheet)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
        }
    }
}

#Preview {
    FeedView_Previews()
        .preferredColorScheme(.dark)
}
