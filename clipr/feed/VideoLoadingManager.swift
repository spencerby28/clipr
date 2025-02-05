import Foundation
import AVFoundation
import Combine

class VideoLoadingManager: ObservableObject {
    private var playerCache: NSCache<NSString, AVPlayer> = {
        let cache = NSCache<NSString, AVPlayer>()
        cache.countLimit = 5 // Limit cached players
        return cache
    }()
    
    @Published private(set) var activePlayer: AVPlayer?
    @Published private(set) var loadedVideos: [Int: AVPlayer] = [:]
    private var videoURLs: [Int: URL] = [:]
    private var preloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var cancellables: Set<AnyCancellable> = []
    
    func setVideos(_ urls: [URL]) {
        // Clear old videos and cache
        loadedVideos.removeAll()
        playerCache.removeAllObjects()
        videoURLs.removeAll()
        
        // Store new URLs
        for (index, url) in urls.enumerated() {
            videoURLs[index] = url
        }
    }
    
    func preparePlayer(for url: URL) -> AVPlayer {
        let key = url.absoluteString as NSString
        if let cachedPlayer = playerCache.object(forKey: key) {
            return cachedPlayer
        }
        
        let player = AVPlayer(url: url)
        playerCache.setObject(player, forKey: key)
        
        // Configure player
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        // Preload buffer
        player.preroll(atRate: 1) { [weak player] finished in
            if finished {
                player?.seek(to: .zero)
            }
        }
        
        return player
    }
    
    func playerFor(index: Int) -> AVPlayer? {
        if let url = videoURLs[index] {
            let player = preparePlayer(for: url)
            loadedVideos[index] = player
            return player
        }
        return nil
    }
    
    func preloadVideosAround(index: Int) {
        // Clear old videos except current and adjacent
        let keepIndices = [index - 1, index, index + 1]
        loadedVideos = loadedVideos.filter { keepIndices.contains($0.key) }
        
        // Preload adjacent videos
        preloadQueue.addOperation { [weak self] in
            guard let self = self else { return }
            for loadIndex in (index-1)...(index+1) {
                if loadIndex >= 0,
                   let url = self.videoURLs[loadIndex],
                   self.loadedVideos[loadIndex] == nil {
                    let player = self.preparePlayer(for: url)
                    DispatchQueue.main.async {
                        self.loadedVideos[loadIndex] = player
                    }
                }
            }
        }
    }
    
    func pauseAllExcept(index: Int) {
        for (playerIndex, player) in loadedVideos where playerIndex != index {
            player.pause()
            player.seek(to: .zero)
        }
    }
    
    deinit {
        cancellables.removeAll()
        playerCache.removeAllObjects()
        loadedVideos.removeAll()
    }
} 
