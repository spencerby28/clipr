import Foundation
import AVFoundation
import CoreImage
import Photos

class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "video.preview.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "video.preview.processing", qos: .userInteractive, attributes: .concurrent)
    private var lastFrameTime = CACurrentMediaTime()
    private let desiredFrameRate: Double = 60.0 // Increased to 60fps
    
    private var addToPreviewStream: ((CGImage) -> Void)?
    private var isCancelled = false
    
    lazy var previewStream: AsyncStream<CGImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { [self] cgImage in
                guard !self.isCancelled else { return }
                continuation.yield(cgImage)
            }
            
            continuation.onTermination = { [self] _ in
                self.isCancelled = true
            }
        }
    }()
    
    private var currentPosition: AVCaptureDevice.Position = .front
    
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var recordingProgress: Double = 0
    @Published private(set) var flipCountdown: Int = 0
    @Published private(set) var countdown: Int = 0
    @Published private(set) var shouldShowCountdown: Bool = false
    
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private let totalRecordingDuration: TimeInterval = 6.0
    private let flipCameraTime: TimeInterval = 3.0
    
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoURLs: [URL] = []
    @Published private(set) var savedVideos: [URL] = []
    
    private var firstHalfURL: URL?
    private var secondHalfURL: URL?
    private var isRecordingFirstHalf = true
    
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    @Published private(set) var lastRecordedVideoURL: URL?
    @Published var showingPreview = false
    
    override init() {
        super.init()
        sessionQueue.async {
            self.setupSession()
        }
    }
    
    deinit {
        print("CameraManager deinit")
        isCancelled = true
        captureSession.stopRunning()
        recordingTimer?.invalidate()
    }
    
    private func setupSession() {
        Task {
            await configureSession()
            startSession()
        }
    }
    
    private var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            return isAuthorized
        }
    }
    
    private func configureSession() async {
        guard await isAuthorized else { return }
        
        // Add audio authorization check
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let audioAuthorized: Bool
        if audioStatus == .authorized {
            audioAuthorized = true
        } else if audioStatus == .notDetermined {
            audioAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        } else {
            audioAuthorized = false
        }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: currentPosition),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { return }
        
        // Setup audio input if authorized
        if audioAuthorized,
           let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            audioDeviceInput = audioInput
        }
        
        captureSession.beginConfiguration()
        
        // Set high quality preset
        captureSession.sessionPreset = .high
        
        do {
            try videoDevice.lockForConfiguration()
            
            // Configure for 60fps
            let formats = videoDevice.formats
            let targetFormat = formats.first { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let maxRate = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0
                return maxRate >= 60.0 && dimensions.width >= 1280
            }
            
            if let format = targetFormat {
                videoDevice.activeFormat = format
                print("Selected format: \(format)")
                
                // Set to 60fps
                let targetFPS = CMTime(value: 1, timescale: 60)
                videoDevice.activeVideoMinFrameDuration = targetFPS
                videoDevice.activeVideoMaxFrameDuration = targetFPS
            }
            
            let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
            print("Camera format: \(dimensions.width)x\(dimensions.height)")
            print("Frame rate: \(videoDevice.activeVideoMinFrameDuration.timescale)")
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error configuring device: \(error)")
        }
        
        // Remove existing inputs/outputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        // Set video output settings for better performance
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeLeft
                print("Set video orientation to landscapeLeft")
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentPosition == .front
                print("Set video mirroring: \(currentPosition == .front)")
            }
        }
        
        guard captureSession.canAddInput(videoDeviceInput),
              captureSession.canAddOutput(videoOutput) else {
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = videoDeviceInput
        self.videoOutput = videoOutput
        
        // Add movie output configuration after existing video output setup
        let movieOutput = AVCaptureMovieFileOutput()
        
        guard captureSession.canAddOutput(movieOutput) else {
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addOutput(movieOutput)
        self.movieOutput = movieOutput
        
        // Add audio input if available
        if let audioInput = audioDeviceInput,
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        isCancelled = false
        guard !captureSession.isRunning else { return }
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        isCancelled = true
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    func toggleCamera() {
        stopSession()
        
        sessionQueue.async {
            self.currentPosition = self.currentPosition == .front ? .back : .front
            Task {
                await self.configureSession()
                self.startSession()
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordingStartTime = Date()
        isRecordingFirstHalf = true

        // Create temporary URL for the first segment.
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_part1_\(Date().timeIntervalSince1970).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Start recording first segment.
        movieOutput?.startRecording(to: fileURL, recordingDelegate: self)
        
        // Begin a timer to track the first segment's duration.
        // When flipCameraTime is reached, stop the movie recording.
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                self.recordingProgress = elapsed / self.totalRecordingDuration
                // Optionally update countdown UI.
                if elapsed < self.flipCameraTime {
                    let timeLeft = self.flipCameraTime - elapsed
                    if timeLeft <= 3 {
                        self.countdown = Int(ceil(timeLeft))
                        self.shouldShowCountdown = timeLeft > 0.1
                    }
                }
                // Stop recording for the first segment at flipCameraTime (5 sec).
                if elapsed >= self.flipCameraTime {
                    self.recordingTimer?.invalidate()
                    self.recordingTimer = nil
                    self.movieOutput?.stopRecording()
                }
            }
        }
    }
    
    private func startSecondHalfRecordingSegment() {
        isRecordingFirstHalf = false
        
        // Create temporary URL for the second segment.
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_part2_\(Date().timeIntervalSince1970).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Start recording the second segment.
        movieOutput?.startRecording(to: fileURL, recordingDelegate: self)
        
        // Reset timer for the second segment.
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                // Update countdown for second segment if needed.
                let timeLeft = (self.totalRecordingDuration - self.flipCameraTime) - elapsed
                if timeLeft <= 3 {
                    self.countdown = Int(ceil(timeLeft))
                    if elapsed >= 2.0 { // e.g. show countdown after 2 sec into segment.
                        self.shouldShowCountdown = true
                    }
                }
                // Stop second recording when its allotted time is reached.
                if elapsed >= (self.totalRecordingDuration - self.flipCameraTime) {
                    timer.invalidate()
                    self.recordingTimer = nil
                    self.movieOutput?.stopRecording()
                }
            }
        }
    }
    
    // Add method to get saved videos
    func loadSavedVideos() {
        // For now, just expose the saved videoURLs
        DispatchQueue.main.async {
            self.savedVideos = self.videoURLs
        }
    }
    
    // Helper method to save video to photo library
    private func saveVideoToPhotoLibrary(fileURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } completionHandler: { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.videoURLs.append(fileURL)
                        self.savedVideos = self.videoURLs
                    }
                } else if let error = error {
                    print("Error saving video: \(error)")
                }
            }
        }
    }
    
    // Add method to combine videos
    private func combineVideos(firstHalfURL: URL, secondHalfURL: URL) async {
        let composition = AVMutableComposition()
        
        // Create video track
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("Failed to create video track")
            return
        }
        
        // Create audio track (optional)
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        do {
            // Load first half asynchronously
            let firstAsset = AVURLAsset(url: firstHalfURL)
            let firstVideoTrack = try await firstAsset.loadTracks(withMediaType: .video)[0]
            let firstDuration = try await firstAsset.load(.duration)
            let firstRange = CMTimeRange(start: .zero, duration: firstDuration)
            
            // Insert video
            try videoTrack.insertTimeRange(firstRange,
                                         of: firstVideoTrack,
                                         at: .zero)
            
            // Insert audio if available
            if let audioTrack = audioTrack,
               let firstAudioTrack = try? await firstAsset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(firstRange,
                                             of: firstAudioTrack,
                                             at: .zero)
            }
            
            // Load second half asynchronously
            let secondAsset = AVURLAsset(url: secondHalfURL)
            let secondVideoTrack = try await secondAsset.loadTracks(withMediaType: .video)[0]
            let secondDuration = try await secondAsset.load(.duration)
            let secondRange = CMTimeRange(start: .zero, duration: secondDuration)
            
            // Insert video
            try videoTrack.insertTimeRange(secondRange,
                                         of: secondVideoTrack,
                                         at: firstDuration)
            
            // Insert audio if available
            if let audioTrack = audioTrack,
               let secondAudioTrack = try? await secondAsset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(secondRange,
                                             of: secondAudioTrack,
                                             at: firstDuration)
            }
            
            // Export combined video
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                print("Failed to create export session")
                return
            }
            
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("final_recording_\(Date().timeIntervalSince1970).mov")
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov
            
            // Create a video composition to rotate the final output by 90° right.
            //
            // We use the natural size from the first video track (assuming both segments match)
            // and set the render size to be swapped (width becomes height and vice-versa).
            let videoComposition = AVMutableVideoComposition()
            videoComposition.frameDuration = CMTime(value: 1, timescale: 60)
            let naturalSize = firstVideoTrack.naturalSize
            videoComposition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            // Rotate by 90° to the right: translate by naturalSize.height then rotate by π/2.
            let rotationTransform = CGAffineTransform(translationX: naturalSize.height, y: 0)
                .rotated(by: .pi/2)
            layerInstruction.setTransform(rotationTransform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            exportSession.videoComposition = videoComposition

            // Perform the export asynchronously.
            await exportSession.export()
            
            if exportSession.status == .completed {
                DispatchQueue.main.async {
                    self.lastRecordedVideoURL = outputURL
                    self.showingPreview = true
                }
                saveVideoToPhotoLibrary(fileURL: outputURL)
            } else if let error = exportSession.error {
                print("Export failed: \(error)")
            }
            
        } catch {
            print("Error combining videos: \(error)")
        }
    }
    
    // Add method to handle video sending
    func sendVideo() async {
        guard let videoURL = lastRecordedVideoURL else { return }
        do {
            let mp4URL = try await convertMovToMp4(inputURL: videoURL)
            let fileId = try await AppwriteManager.shared.uploadVideo(fileURL: mp4URL)
            print("Video uploaded successfully with ID: \(fileId)")
            // Handle successful upload (e.g., save to user's posts)
        } catch {
            print("Error uploading video: \(error)")
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - lastFrameTime
        
        // More permissive frame rate check
        guard elapsed >= (1.0 / (desiredFrameRate * 1.1)) else { return }
        lastFrameTime = currentTime
        
        guard var currentFrame = sampleBuffer.cgImage else { return }
        
        // Use strong reference for image processing
        processingQueue.async {
            if let rotatedImage = self.rotateImage(currentFrame, byDegrees: -90) {
                currentFrame = rotatedImage
                
                if self.currentPosition == .front {
                    if let mirroredImage = self.mirrorImage(currentFrame) {
                        currentFrame = mirroredImage
                    }
                }
                
                self.addToPreviewStream?(currentFrame)
            }
        }
    }
    
    private func rotateImage(_ image: CGImage, byDegrees degrees: CGFloat) -> CGImage? {
        let radians = degrees * .pi / 180.0
        let contextWidth = CGFloat(image.height)
        let contextHeight = CGFloat(image.width)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(contextWidth),
            height: Int(contextHeight),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.translateBy(x: contextWidth / 2, y: contextHeight / 2)
        context.rotate(by: radians)
        context.translateBy(x: -contextHeight / 2, y: -contextWidth / 2)
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        
        return context.makeImage()
    }
    
    private func mirrorImage(_ image: CGImage) -> CGImage? {
        let contextWidth = CGFloat(image.width)
        let contextHeight = CGFloat(image.height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(contextWidth),
            height: Int(contextHeight),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.translateBy(x: contextWidth, y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: contextWidth, height: contextHeight))
        
        return context.makeImage()
    }
}

// Update the delegate methods
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                   didFinishRecordingTo outputFileURL: URL,
                   from connections: [AVCaptureConnection],
                   error: Error?) {
        if let error = error {
            print("Error recording video: \(error)")
            return
        }
        
        if isRecordingFirstHalf {
            // First segment finished.
            firstHalfURL = outputFileURL
            
            // Toggle the camera after the first recording.
            toggleCamera()
            
            // After a short delay to allow for session reconfiguration,
            // start recording the second segment.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startSecondHalfRecordingSegment()
            }
            
        } else {
            // Second segment finished.
            secondHalfURL = outputFileURL
            
            // Combine the two segments.
            if let firstHalfURL = firstHalfURL,
               let secondHalfURL = secondHalfURL {
                Task {
                    await combineVideos(firstHalfURL: firstHalfURL,
                                      secondHalfURL: secondHalfURL)
                }
            }
            
            // Reset recording state.
            DispatchQueue.main.async {
                self.isRecording = false
                self.recordingProgress = 0
                self.countdown = 0
                self.shouldShowCountdown = false
            }
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                   didStartRecordingTo fileURL: URL,
                   from connections: [AVCaptureConnection]) {
        print("Started recording to: \(fileURL)")
    }
} 
