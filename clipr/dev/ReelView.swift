//
//  ReelView.swift
//  ReelsLayout
//
//  Created by Balaji Venkatesh on 13/11/23.
//

import SwiftUI
import AVKit

/// Reel View
struct ReelView: View {
    @Binding var reel: Reel
    @Binding var likedCounter: [devLike]
    var size: CGSize
    var safeArea: EdgeInsets
    var currentIndex: Int
    @Binding var allReels: [Reel]
    /// View Properties
    @StateObject private var playerManager = PlayerManager()
    @State private var isLoading: Bool = true
    var body: some View {
        GeometryReader {
            let rect = $0.frame(in: .scrollView(axis: .vertical))
            
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                /// Custom Video Player View
                DevCustomVideoPlayer(player: $playerManager.player)
                    /// Offset Updates
                    .preference(key: OffsetKey.self, value: rect)
                    .onPreferenceChange(OffsetKey.self, perform: { value in
                        playPause(value)
                    })
            }
            .overlay(alignment: .bottom, content: {
                ReelDetailsView()
            })
            /// Double Tap Like Animation
            .onTapGesture(count: 2, perform: { position in
                let id = UUID()
                likedCounter.append(.init(id: id, tappedRect: position, isAnimated: false))
                /// Animating Like
                withAnimation(.snappy(duration: 1.2), completionCriteria: .logicallyComplete) {
                    if let index = likedCounter.firstIndex(where: { $0.id == id }) {
                        likedCounter[index].isAnimated = true
                    }
                } completion: {
                    /// Removing Like, Once it's Finished
                    likedCounter.removeAll(where: { $0.id == id })
                }
                
                /// Liking the Reel
                reel.isLiked = true
            })
            /// Creating Player
            .onAppear {
                guard let url = URL(string: reel.videoID) else { return }
                playerManager.setupPlayer(with: url)
                // Trigger preloading
                playerManager.preloadVideos(currentIndex: currentIndex, videos: allReels)
            }
            /// Clearing Player
            .onDisappear {
                playerManager.cleanup()
            }
        }
    }
    /// Play/Pause Action
    func playPause(_ rect: CGRect) {
        if -rect.minY < (rect.height * 0.5) && rect.minY < (rect.height * 0.5) {
            playerManager.player?.play()
        } else {
            playerManager.player?.pause()
        }
        
        if rect.minY >= size.height || -rect.minY >= size.height {
            playerManager.player?.seek(to: .zero)
        }
    }
    
    /// Reel Details & Controls
    @ViewBuilder
    func ReelDetailsView() -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 8, content: {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                    
                    Text(reel.authorName)
                        .font(.callout)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                
                Text("Lorem Ipsum is simply dummy text of the printing and typesetting industry")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .clipped()
            })
            
            Spacer(minLength: 0)
            
            /// Controls View
            VStack(spacing: 35) {
                Button("", systemImage: reel.isLiked ? "suit.heart.fill" : "suit.heart") {
                    reel.isLiked.toggle()
                }
                .symbolEffect(.bounce, value: reel.isLiked)
                .foregroundStyle(reel.isLiked ? .red : .white)
                
                Button("", systemImage: "message") {  }
                
                Button("", systemImage: "paperplane") {  }
                
                Button("", systemImage: "ellipsis") {  }
            }
            .font(.title2)
            .foregroundStyle(.white)
        }
        .padding(.leading, 15)
        .padding(.trailing, 10)
        .padding(.bottom, safeArea.bottom + 15)
    }
}
class PlayerManager: NSObject, ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading: Bool = true
    
    // Cache for preloaded players
    private var preloadedPlayers: [String: AVPlayer] = [:]
    private let preloadLimit = 2 // Number of videos to preload in each direction
    
    func preloadVideos(currentIndex: Int, videos: [Reel]) {
        // Clear old preloaded videos that are no longer needed
        preloadedPlayers.removeAll()
        
        // Calculate range of videos to preload
        let startIndex = max(0, currentIndex - preloadLimit)
        let endIndex = min(videos.count - 1, currentIndex + preloadLimit)
        
        // Preload videos within range
        for index in startIndex...endIndex where index != currentIndex {
            let videoURL = videos[index].videoID
            guard let url = URL(string: videoURL),
                  preloadedPlayers[videoURL] == nil else { continue }
            
            let playerItem = AVPlayerItem(url: url)
            let newPlayer = AVQueuePlayer(playerItem: playerItem)
            preloadedPlayers[videoURL] = newPlayer
            
            // Preload the video by starting and immediately pausing
            newPlayer.preroll(atRate: 1) { [weak self] finished in
                if finished {
                    newPlayer.pause()
                }
            }
        }
    }
    
    func setupPlayer(with url: URL) {
        // Check if we have a preloaded player for this URL
        if let preloadedPlayer = preloadedPlayers[url.absoluteString] {
            player = preloadedPlayer
            preloadedPlayers.removeValue(forKey: url.absoluteString)
            player?.seek(to: .zero)
            player?.play()
            return
        }
        
        // If no preloaded player, create a new one
        guard player == nil else { return }
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVQueuePlayer(playerItem: playerItem)
        
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        
        player = newPlayer
        newPlayer.play()
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
    }
    
    func cleanup() {
        if let player = player {
            player.pause()
            NotificationCenter.default.removeObserver(self)
            if let playerItem = player.currentItem {
                playerItem.removeObserver(self, forKeyPath: "status")
            }
        }
        player = nil
        
        // Cleanup preloaded players
        preloadedPlayers.values.forEach { player in
            player.pause()
        }
        preloadedPlayers.removeAll()
    }
}

#Preview {
    ContentView()
}
