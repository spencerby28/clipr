//
//  CustomVideoPlayer.swift
//  ReelsLayout
//
//  Created by Balaji Venkatesh on 13/11/23.
//

import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
    @Binding var player: AVPlayer?
    @ObservedObject var videoManager: VideoLoadingManager
    let index: Int
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = videoManager.playerFor(index: index)
        controller.videoGravity = .resizeAspectFill
        controller.showsPlaybackControls = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = videoManager.playerFor(index: index)
    }
}
