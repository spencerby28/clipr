import Foundation
import AVFoundation
import Combine

class VideoLoadingManager: ObservableObject {
    /// Tracks which video index is currently focused/visible. 
    /// This can help us decide which ones to preload or play/pause.
    @Published var currentVideoIndex: Int = 0
    
    /// A dictionary of loaded AVPlayers keyed by the index from the feed.
    @Published var loadedVideos: [Int: AVPlayer] = [:]
    
    /// A dictionary of video URLs keyed by index. This is populated in setVideos.
    private var videoURLs: [Int: URL] = [:]
    
    /// Combine cancellables for observing player readiness.
    private var cancellables: Set<AnyCancellable> = []
    
    /// Assigns the given array of URLs to their respective indices.
    /// Here, we also immediately instantiate AVPlayers for each URL
    /// so playerFor(index:) doesn't return nil.
    func setVideos(_ urls: [URL]) {
        print("DEBUG: VideoLoadingManager - Setting \(urls.count) videos")
        
        // Store all URLs first
        for (index, url) in urls.enumerated() {
            videoURLs[index] = url
        }
        
        // Initially load first 3 videos
        for index in 0...min(2, urls.count - 1) {
            createPlayerIfNeeded(at: index)
        }
    }
    
    private func createPlayerIfNeeded(at index: Int) {
        guard loadedVideos[index] == nil,
              let url = videoURLs[index] else { return }
        
        print("DEBUG: VideoLoadingManager - Creating new player for index \(index)")
        let player = AVPlayer(url: url)
        loadedVideos[index] = player
        
        // Observe player status
        player.publisher(for: \.status)
            .sink { [weak self] status in
                print("DEBUG: VideoLoadingManager - Player \(index) status changed to: \(status.rawValue)")
                if status == .readyToPlay {
                    print("DEBUG: VideoLoadingManager - Player \(index) is ready to play")
                    player.seek(to: .zero)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Loads (or keeps) players for index-1, index, index+1 in memory, discarding others.
    /// If you want to keep more players, you can tweak the range.
    func preloadVideosAround(index: Int) {
        print("DEBUG: VideoLoadingManager - Preloading around index \(index)")
        
        // Keep a window of 5 videos (current ± 2)
        let keepRange = max(0, index - 2)...min(videoURLs.count - 1, index + 2)
        print("DEBUG: VideoLoadingManager - Planning to keep indices \(keepRange)")
        
        // Create new players for the range
        keepRange.forEach { createPlayerIfNeeded(at: $0) }
        
        // Only remove players far outside our range (±3) to prevent thrashing
        let extendedRange = max(0, index - 3)...min(videoURLs.count - 1, index + 3)
        for (loadedIndex, player) in loadedVideos {
            if !extendedRange.contains(loadedIndex) {
                print("DEBUG: VideoLoadingManager - Removing distant player at index \(loadedIndex)")
                player.pause()
                player.replaceCurrentItem(with: nil)
                loadedVideos.removeValue(forKey: loadedIndex)
            }
        }
        
        print("DEBUG: VideoLoadingManager - Current loaded indices: \(loadedVideos.keys.sorted())")
    }
    
    /// Return the AVPlayer for the requested index, if it exists.
    func playerFor(index: Int) -> AVPlayer? {
        if loadedVideos[index] == nil {
            print("DEBUG: VideoLoadingManager - Player requested for index \(index) but not found")
            createPlayerIfNeeded(at: index)
        }
        return loadedVideos[index]
    }
    
    /// Pause all players except the one at the provided index.  
    /// Useful when user scrolls to a new video in the feed.
    func pauseAllExcept(index: Int) {
        print("DEBUG: VideoLoadingManager - Pausing all except index \(index)")
        for (playerIndex, player) in loadedVideos {
            if playerIndex != index {
                player.pause()
                player.seek(to: .zero)
            }
        }
    }
    
    /// As an optional helper, if you want to check and possibly preload
    /// around the currently focused index. E.g., if we detect that index
    /// is ready, we can prime the next index. 
    private func maybePreloadAround(index: Int) {
        // This is just an internal helper. You could call
        // preloadVideosAround(index:) here if desired, or do nothing.
    }
    
    deinit {
        cancellables.removeAll()
    }
} 
