import SwiftUI
import AVFoundation

struct CustomVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        // Force the view to have a size
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer else { return }
        
        // Ensure animations are disabled for frame updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = uiView.bounds
        CATransaction.commit()
        
        // Force layout if needed
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
    }
} 