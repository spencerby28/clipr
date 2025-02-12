//
//  FeedViewModel.swift
//  clipr
//
//  Created by Spencer Byrne on 2/11/25.
//

import Foundation
import SwiftUI

class FeedViewModel: ObservableObject {
    @Published var videos: [VideoWithMetadata] = []
    @Published var loadingState: LoadingState = .idle
    @Published var currentPage: Int = 1
    private let pageSize = 10
    private var hasMoreContent = true
    private var isLoadingMore = false
    private var videoManager: VideoLoadingManager?
    
    init() {
        print("DEBUG: FeedViewModel - Initialized")
    }
    
    func setVideoManager(_ manager: VideoLoadingManager) {
        self.videoManager = manager
        print("DEBUG: FeedViewModel - VideoManager connected")
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
        guard let videoManager = videoManager else {
            print("DEBUG: FeedViewModel - Cannot load videos, videoManager not set")
            return
        }
        
        print("DEBUG: FeedViewModel - loadVideos called. Refresh: \(refresh), Current page: \(currentPage), HasMoreContent: \(hasMoreContent), IsLoadingMore: \(isLoadingMore)")

        if refresh {
            currentPage = 1
            videos = []
            hasMoreContent = true
            print("DEBUG: FeedViewModel - Refresh triggered. Reset state: page=1, videos=[], hasMoreContent=true")
        }
        
        guard hasMoreContent && !isLoadingMore else {
            print("DEBUG: FeedViewModel - Skipping load. hasMoreContent=\(hasMoreContent), isLoadingMore=\(isLoadingMore)")
            return
        }
        
        isLoadingMore = true
        
        if videos.isEmpty {
            loadingState = .loading
            print("DEBUG: FeedViewModel - Videos array empty, setting loadingState to .loading")
        }
        
        do {
            print("DEBUG: FeedViewModel - Fetching videos from AppwriteManager. Page: \(currentPage), Offset: \((currentPage - 1) * pageSize)")
            let newVideos = try await AppwriteManager.shared.listVideosWithMetadata(
                limit: pageSize,
                offset: (currentPage - 1) * pageSize
            )
            
            print("DEBUG: FeedViewModel - Received \(newVideos.count) new videos")
            
            let videoWithMetadata = newVideos.map { video in
                print("DEBUG: FeedViewModel - Creating VideoWithMetadata for video ID: \(video.id)")
                return VideoWithMetadata(
                    id: video.id,
                    metadata: video
                )
            }
            
            await MainActor.run {
                if refresh {
                    print("DEBUG: FeedViewModel - Replacing videos array with \(videoWithMetadata.count) new videos")
                    self.videos = videoWithMetadata
                } else {
                    print("DEBUG: FeedViewModel - Appending \(videoWithMetadata.count) videos to existing \(self.videos.count) videos")
                    self.videos.append(contentsOf: videoWithMetadata)
                }
                
                self.currentPage += 1
                self.hasMoreContent = videoWithMetadata.count == pageSize
                self.loadingState = .loaded
                self.isLoadingMore = false
                
                print("DEBUG: FeedViewModel - State updated: page=\(self.currentPage), hasMore=\(self.hasMoreContent), state=.loaded")
                
                // Update VideoLoadingManager with ALL video URLs
                let allUrls = self.videos.compactMap { $0.url }
                print("DEBUG: FeedViewModel - Setting \(allUrls.count) URLs in VideoLoadingManager")
                videoManager.setVideos(allUrls)
            }
        } catch {
            await MainActor.run {
                print("ERROR: FeedViewModel - Failed to load videos: \(error.localizedDescription)")
                self.loadingState = .error(error.localizedDescription)
                self.isLoadingMore = false
            }
        }
    }
}
