import Foundation
import CoreImage
import SwiftUI

class CameraViewModel: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var isRecording: Bool = false
    private var cameraManager: CameraManager?
    private var previewTask: Task<Void, Never>?
    
    init() {
        print("CameraViewModel init")
    }
    
    deinit {
        print("CameraViewModel deinit")
        stopPreviewStream()
    }
    
    func startPreviewStream() {
        print("Starting preview stream")
        stopPreviewStream()
        
        // Create new CameraManager if needed
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
    
    func toggleRecording() {
        isRecording.toggle()
    }
} 