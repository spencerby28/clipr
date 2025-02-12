//
//  FeedViewModel.swift
//  clipr
//
//  Created by Spencer Byrne on 2/11/25.
//

import Foundation
import SwiftUI
import Kingfisher

class FeedViewModel: ObservableObject {
    @Published var videos: [VideoWithMetadata] = []
    @Published var loadingState: LoadingState = .idle
    @Published var currentPage: Int = 1
    private let pageSize = 10
    private var hasMoreContent = true
    private var isLoadingMore = false
    private var videoManager: VideoLoadingManager?
    
    init() {}
    
    func setVideoManager(_ manager: VideoLoadingManager) {
        self.videoManager = manager
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
    func preloadThumbnails(startIndex: Int) {
        let endIndex = min(startIndex + 10, videos.count)
        let batchUrls = videos[startIndex..<endIndex]
            .compactMap { $0.metadata.thumbnailURL }
        
        if !batchUrls.isEmpty {
            print("🖼️ Feed: Preloading thumbnails \(startIndex)-\(endIndex-1)")
            
            let prefetcher = ImagePrefetcher(
                urls: batchUrls,
                options: [
                    .backgroundDecode,
                    .loadDiskFileSynchronously,
                ], completionHandler:  { skippedResources, failedResources, completedResources in
                    if !failedResources.isEmpty {
                        print("⚠️ Feed: Failed to load \(failedResources.count) thumbnails")
                    }
                })
            prefetcher.start()
        }
    }
    
    @MainActor
    func loadVideos(refresh: Bool = false) async {
        guard let videoManager = videoManager else {
            print("❌ Feed: Cannot load videos - no video manager")
            return
        }
        
        if refresh {
            print("🔄 Feed: Refreshing feed")
            currentPage = 1
            videos = []
            hasMoreContent = true
        }
        
        guard hasMoreContent && !isLoadingMore else { return }
        
        isLoadingMore = true
        
        if videos.isEmpty {
            loadingState = .loading
        }
        
        do {
            print("📥 Feed: Loading page \(currentPage)")
            let newVideos = try await AppwriteManager.shared.listVideosWithMetadata(
                limit: pageSize,
                offset: (currentPage - 1) * pageSize
            )
            
            await MainActor.run {
                if refresh {
                    print("✨ Feed: Replacing with \(newVideos.count) new videos")
                    self.videos = newVideos.map { VideoWithMetadata(id: $0.id, metadata: $0) }
                    preloadThumbnails(startIndex: 0)
                } else {
                    print("✨ Feed: Appending \(newVideos.count) videos")
                    self.videos.append(contentsOf: newVideos.map { VideoWithMetadata(id: $0.id, metadata: $0) })
                    preloadThumbnails(startIndex: self.videos.count - newVideos.count)
                }
                
                self.currentPage += 1
                self.hasMoreContent = newVideos.count == pageSize
                self.loadingState = .loaded
                self.isLoadingMore = false
                
                // Update VideoLoadingManager with ALL video URLs
                let allUrls = self.videos.compactMap { $0.url }
                videoManager.setVideos(allUrls)
            }
        } catch {
            await MainActor.run {
                print("❌ Feed: Failed to load videos - \(error.localizedDescription)")
                self.loadingState = .error(error.localizedDescription)
                self.isLoadingMore = false
            }
        }
    }
    
    deinit {
        // No need for cleanup since we're not storing the prefetcher
    }
}

