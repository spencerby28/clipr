import Foundation
import AVFoundation
import SwiftUI

class VideoPlayerManager: NSObject, ObservableObject {
    let player = AVPlayer()
    @Published var progress: Double = 0.0
    @Published var isLoading: Bool = false

    private var timeObserverToken: Any?

    override init() {
        super.init()
        addPeriodicTimeObserver()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    private func addPeriodicTimeObserver() {
        // Update every 0.1 seconds.
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let currentItem = self.player.currentItem else {
                self?.progress = 0.0
                return
            }
            let duration = currentItem.duration.seconds
            if duration > 0 {
                self.progress = time.seconds / duration
            } else {
                self.progress = 0.0
            }
        }
    }

    func setVideo(url: URL) {
        print("Setting video with URL: \(url)")
        self.isLoading = true
        
        // Reset player
        player.pause()
        
        let playerItem = AVPlayerItem(url: url)
        
        // Add error handling
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerItemDidFailToPlay),
                                             name: .AVPlayerItemFailedToPlayToEndTime,
                                             object: playerItem)
        
        // Add playback ended notification
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerItemDidReachEnd),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: playerItem)
        
        // Observe playerItem's status to determine when it's ready
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        player.replaceCurrentItem(with: playerItem)
    }

    @objc private func playerItemDidFailToPlay(_ notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            print("Video failed to play: \(error)")
        }
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        // Loop playback
        player.seek(to: .zero)
        player.play()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                print("Player item ready to play")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                playerItem.removeObserver(self, forKeyPath: "status")
            case .failed:
                print("Player item failed: \(String(describing: playerItem.error))")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                playerItem.removeObserver(self, forKeyPath: "status")
            case .unknown:
                print("Player item status unknown")
            @unknown default:
                break
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func play() {
        print("Playing video")
        if player.currentItem?.status == .readyToPlay {
            player.play()
        } else {
            print("Attempted to play but player item not ready")
        }
    }

    func pause() {
        print("Pausing video")
        player.pause()
    }
}

