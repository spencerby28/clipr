import Foundation
import CoreImage
import SwiftUI

@Observable
class CameraViewModel {
    var currentFrame: CGImage?
    var isRecording: Bool = false
    private let cameraManager: CameraManager
    private var previewTask: Task<Void, Never>?
    
    init() {
        self.cameraManager = CameraManager()
        startPreviewStream()
    }
    
    deinit {
        previewTask?.cancel()
    }
    
    private func startPreviewStream() {
        previewTask = Task { [weak self] in
            await self?.handleCameraPreviews()
        }
    }
    
    private func handleCameraPreviews() async {
        for await image in cameraManager.previewStream {
            await MainActor.run {
                currentFrame = image
            }
        }
    }
    
    func toggleCamera() {
        cameraManager.toggleCamera()
    }
    
    func toggleRecording() {
        isRecording.toggle()
    }
} 