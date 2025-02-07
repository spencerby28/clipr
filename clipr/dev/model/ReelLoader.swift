import Foundation
import Appwrite
import SwiftUI

@MainActor
class ReelLoader: ObservableObject {
    @Published var reels: [Reel] = []
    @Published var loadingState: LoadingState = .idle
    @Published var currentPage: Int = 1
    
    private let pageSize = 10
    private var hasMoreContent = true
    private var isLoadingMore = false
    
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
    
    func loadReels(refresh: Bool = false) async {
        print("DEBUG: loadReels called with refresh = \(refresh). Current page = \(currentPage)")
        
        if refresh {
            currentPage = 1
            reels = []
            hasMoreContent = true
            print("DEBUG: Refreshing. Resetting page to 1 and clearing reels.")
        }
        
        guard hasMoreContent && !isLoadingMore else {
            print("DEBUG: hasMoreContent = \(hasMoreContent), isLoadingMore = \(isLoadingMore). Aborting load.")
            return
        }
        
        isLoadingMore = true
        
        if reels.isEmpty {
            loadingState = .loading
            print("DEBUG: reels array is empty. Setting loading state to .loading.")
        }
        
        do {
            print("DEBUG: About to call listVideosWithMetadata. Limit = \(pageSize), offset = \((currentPage - 1) * pageSize)")
            let newVideos = try await AppwriteManager.shared.listVideosWithMetadata(
                limit: pageSize,
                offset: (currentPage - 1) * pageSize
            )
            
            print("DEBUG: listVideosWithMetadata returned \(newVideos.count) video(s).")
            
            let newReels = newVideos.compactMap { video -> Reel? in
                guard let videoId = video.videoId else { return nil }
                let videoURL = AppwriteManager.shared.getVideoURL(
                    fileId: videoId,
                    bucketId: AppwriteManager.bucketId
                )?.absoluteString ?? ""
                
                return Reel(
                    videoID: videoURL,
                    authorName: video.users?.username ?? "Unknown",
                    isLiked: false // You might want to fetch this from user preferences
                )
            }
            
            await MainActor.run {
                if refresh {
                    self.reels = newReels
                } else {
                    self.reels.append(contentsOf: newReels)
                }
                
                print("DEBUG: Now have \(self.reels.count) total reels stored in ReelLoader.")
                
                self.currentPage += 1
                self.hasMoreContent = newReels.count == pageSize
                self.loadingState = .loaded
                self.isLoadingMore = false
            }
            
        } catch {
            await MainActor.run {
                self.loadingState = .error(error.localizedDescription)
                self.isLoadingMore = false
            }
            print("ERROR: Failed to load reels: \(error.localizedDescription)")
        }
    }
    
    func getURLs() -> [URL] {
        return reels.compactMap { URL(string: $0.videoID) }
    }
} 
