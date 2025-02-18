import SwiftUI
import Appwrite
import AVKit

struct FeedView: View {
    @StateObject private var videoManager = VideoLoadingManager.shared
    @StateObject private var viewModel: FeedViewModel
    @State private var currentIndex: Int? = 0
    @State private var selectedFeed: FeedType = .friends
    @State private var isFeedExpanded: Bool = false
    @State private var showSettingsSheet = false
    @State private var showProfileSheet = false
    
    init() {
        _viewModel = StateObject(wrappedValue: FeedViewModel())
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch viewModel.loadingState {
                case .idle, .loading:
                    LoadingView()
                case .error(let msg):
                    Text("ERROR: \(msg)")
                case .loaded:
                    Text("LOADED with \(viewModel.videos.count) videos")
                    ZStack {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                    VideoCell(video: video, index: index, videoManager: videoManager)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .edgesIgnoringSafeArea(.all)
                                        .id(index)
                                        .onAppear {
                                            print("DEBUG: FeedView - Video cell \(index) appeared, total videos: \(viewModel.videos.count)")
                                            // Only trigger loading if we're within bounds and near the end
                                            if index >= viewModel.videos.count - 3 && index < viewModel.videos.count {
                                                print("DEBUG: FeedView - Near end of feed (index \(index)), triggering load of more videos")
                                                Task {
                                                    await viewModel.loadVideos()
                                                }
                                            }
                                        }
                                }
                            }
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $currentIndex)
                        .onChange(of: currentIndex) { oldValue, newValue in
                            print("DEBUG: FeedView - Scroll position changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                            handleScrollPositionChange(oldValue: oldValue, newValue: newValue)
                        }
                        .refreshable {
                            print("DEBUG: FeedView - Pull-to-refresh triggered")
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
            .onAppear {
                viewModel.setVideoManager(videoManager)
                print("FeedView onAppear: Connected videoManager to viewModel")
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func handleScrollPositionChange(oldValue: Int?, newValue: Int?) {
        guard let index = newValue else { 
            print("DEBUG: FeedView - Scroll position changed but new index is nil")
            return 
        }
        
        print("DEBUG: FeedView - Scroll position changed from \(String(describing: oldValue)) to \(index)")
        
        // Pause all videos except current
        videoManager.pauseAllExcept(index: index)
        print("DEBUG: FeedView - Paused all videos except index \(index)")
        
        // Preload adjacent videos
        videoManager.preloadVideosAround(index: index)
        print("DEBUG: FeedView - Triggered preloading around index \(index)")
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Image("clipr-trans")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(rotation))
                .preferredColorScheme(.light)
                .onAppear {
                    // Start rotation after 0.5s delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                }

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
   // FeedView_Previews()
     //   .preferredColorScheme(.dark)
    LoadingView()
}
