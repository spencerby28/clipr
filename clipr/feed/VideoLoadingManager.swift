import Foundation
import AVFoundation
import Combine

class VideoLoadingManager: ObservableObject {
    @Published var currentVideoIndex: Int = 0
    @Published var loadedVideos: [Int: AVPlayer] = [:]
    private var videoURLs: [Int: URL] = [:]
    private var cancellables: Set<AnyCancellable> = []
    
    func setVideos(_ urls: [URL]) {
        for (index, url) in urls.enumerated() {
            videoURLs[index] = url
        }
    }
    
    func preloadVideosAround(index: Int) {
        // Clear old videos except current
        let keepIndices = [index - 1, index, index + 1]
        loadedVideos = loadedVideos.filter { keepIndices.contains($0.key) }
        
        // Preload adjacent videos
        for loadIndex in (index-1)...(index+1) {
            if loadIndex >= 0 && loadIndex < videoURLs.count && loadedVideos[loadIndex] == nil {
                if let url = videoURLs[loadIndex] {
                    let player = AVPlayer(url: url)
                    loadedVideos[loadIndex] = player
                    
                    // Observe player status and preroll only when ready
                    player.publisher(for: \.status)
                        .filter { $0 == .readyToPlay }
                        .first()
                        .sink { [weak self] _ in
                            guard self?.loadedVideos[loadIndex] != nil else { return }
                            player.preroll(atRate: 1) { finished in
                                if finished {
                                    // Optionally seek to beginning
                                    player.seek(to: .zero)
                                }
                            }
                        }
                        .store(in: &cancellables)
                }
            }
        }
    }
    
    func playerFor(index: Int) -> AVPlayer? {
        return loadedVideos[index]
    }
    
    func pauseAllExcept(index: Int) {
        for (playerIndex, player) in loadedVideos where playerIndex != index {
            player.pause()
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
} 
