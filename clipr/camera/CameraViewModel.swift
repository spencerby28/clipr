import Foundation
import CoreImage
import SwiftUI

class CameraViewModel: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var isRecording: Bool = false
    @Published var isProcessingVideo: Bool = false
    private var cameraManager: CameraManager?
    private var previewTask: Task<Void, Never>?
    
    init() {
        print("CameraViewModel init")
        setupCameraManager()
    }
    
    private func setupCameraManager() {
        cameraManager = CameraManager()
        cameraManager?.onVideoProcessingStateChanged = { [weak self] isProcessing in
            DispatchQueue.main.async {
                self?.isProcessingVideo = isProcessing
            }
        }
    }
    
    deinit {
        print("CameraViewModel deinit")
        stopPreviewStream()
    }
    
    func startPreviewStream() {
        print("Starting preview stream")
        stopPreviewStream()
        if cameraManager == nil {
            cameraManager = CameraManager()
        }
        previewTask = Task {
            guard let manager = cameraManager else { return }
            for await image in manager.previewStream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.currentFrame = image
                }
            }
        }
    }
    
    func stopPreviewStream() {
        print("Stopping preview stream")
        previewTask?.cancel()
        previewTask = nil
        currentFrame = nil
        cameraManager = nil
    }
    
    func toggleCamera() {
        cameraManager?.toggleCamera()
    }
    
    func startRecording() {
        cameraManager?.startRecording()
    }
    
    // Computed properties to expose CameraManager's state.
    var topBarProgress: CGFloat {
        cameraManager?.topBarProgress ?? 0.0
    }
    
    var recordButtonProgress: CGFloat {
        cameraManager?.recordButtonProgress ?? 0.0
    }
    
    var countdown: Int {
        cameraManager?.countdown ?? 0
    }
    
    var shouldShowCountdown: Bool {
        cameraManager?.shouldShowCountdown ?? false
    }
} 