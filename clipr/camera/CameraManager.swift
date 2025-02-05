import Foundation
import AVFoundation
import CoreImage
import Photos

class CameraManager: NSObject, ObservableObject {
    // MARK: - Capture Session & Related Properties
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
    @Published private(set) var recordingProgress: Double = 0  // (legacy use, not used in the new UI)
    @Published private(set) var flipCountdown: Int = 0
    @Published private(set) var countdown: Int = 0
    @Published private(set) var shouldShowCountdown: Bool = false
    
    // New published properties for our two-part progress UI:
    // • topBarProgress controls the white progress bar at the top.
    // • recordButtonProgress is passed to our circular record button.
    @Published var topBarProgress: CGFloat = 0.0
    @Published var recordButtonProgress: CGFloat = 0.0
    @Published var isSecondSegment: Bool = false

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
            var isAuth = status == .authorized
            if status == .notDetermined {
                isAuth = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuth
        }
    }
    
    private func configureSession() async {
        guard await isAuthorized else { return }
        
        // Audio authorization check
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
        captureSession.sessionPreset = .high
        
        do {
            try videoDevice.lockForConfiguration()
            let formats = videoDevice.formats
            let targetFormat = formats.first { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let maxRate = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0
                return maxRate >= 60.0 && dimensions.width >= 1280
            }
            
            if let format = targetFormat {
                videoDevice.activeFormat = format
                print("Selected format: \(format)")
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
        
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
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
        
        let movieOutput = AVCaptureMovieFileOutput()
        guard captureSession.canAddOutput(movieOutput) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(movieOutput)
        self.movieOutput = movieOutput
        
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
    
    // MARK: - Recording Methods
    
    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordingStartTime = Date()
        isRecordingFirstHalf = true
        
        // Reset progress tracking for first segment.
        self.isSecondSegment = false
        self.topBarProgress = 0.0
        self.recordButtonProgress = 0.0
        self.countdown = 0
        self.shouldShowCountdown = false
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_part1_\(Date().timeIntervalSince1970).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        movieOutput?.startRecording(to: fileURL, recordingDelegate: self)
        
        // Timer for first segment (expanding white bar & circular progress fills from 0 to 0.5)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                self.topBarProgress = min(1.0, elapsed / self.flipCameraTime)
                self.recordButtonProgress = (elapsed / self.flipCameraTime) * 0.5
                if elapsed < self.flipCameraTime {
                    let timeLeft = self.flipCameraTime - elapsed
                    if timeLeft <= 3 {
                        self.countdown = Int(ceil(timeLeft))
                        self.shouldShowCountdown = timeLeft > 0.1
                    }
                }
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
        self.isSecondSegment = true
        self.topBarProgress = 1.0  // Start with full white bar.
        self.recordButtonProgress = 0.5
        recordingStartTime = Date()
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_part2_\(Date().timeIntervalSince1970).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        movieOutput?.startRecording(to: fileURL, recordingDelegate: self)
        
        // Timer for second segment (white bar shrinks; record button fills from 0.5 to 1.0)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                let segmentDuration = self.totalRecordingDuration - self.flipCameraTime
                self.topBarProgress = max(0.0, 1.0 - (elapsed / segmentDuration))
                self.recordButtonProgress = min(1.0, 0.5 + (elapsed / segmentDuration) * 0.5)
                let remaining = segmentDuration - elapsed
                if remaining <= 3 {
                    self.countdown = Int(ceil(remaining))
                    self.shouldShowCountdown = remaining > 0.1
                }
                if elapsed >= segmentDuration {
                    timer.invalidate()
                    self.recordingTimer = nil
                    self.movieOutput?.stopRecording()
                }
            }
        }
    }
    
    // MARK: - Video Saving & Combining (unchanged)
    
    func loadSavedVideos() {
        DispatchQueue.main.async {
            self.savedVideos = self.videoURLs
        }
    }
    
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
    
    private func combineVideos(firstHalfURL: URL, secondHalfURL: URL) async {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("Failed to create video track")
            return
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        do {
            let firstAsset = AVURLAsset(url: firstHalfURL)
            let firstVideoTrack = try await firstAsset.loadTracks(withMediaType: .video)[0]
            let firstDuration = try await firstAsset.load(.duration)
            let firstRange = CMTimeRange(start: .zero, duration: firstDuration)
            try videoTrack.insertTimeRange(firstRange,
                                         of: firstVideoTrack,
                                         at: .zero)
            if let audioTrack = audioTrack,
               let firstAudioTrack = try? await firstAsset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(firstRange,
                                             of: firstAudioTrack,
                                             at: .zero)
            }
            let secondAsset = AVURLAsset(url: secondHalfURL)
            let secondVideoTrack = try await secondAsset.loadTracks(withMediaType: .video)[0]
            let secondDuration = try await secondAsset.load(.duration)
            let secondRange = CMTimeRange(start: .zero, duration: secondDuration)
            try videoTrack.insertTimeRange(secondRange,
                                         of: secondVideoTrack,
                                         at: firstDuration)
            if let audioTrack = audioTrack,
               let secondAudioTrack = try? await secondAsset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(secondRange,
                                             of: secondAudioTrack,
                                             at: firstDuration)
            }
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
            
            let videoComposition = AVMutableVideoComposition()
            videoComposition.frameDuration = CMTime(value: 1, timescale: 60)
            let naturalSize = firstVideoTrack.naturalSize
            videoComposition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let rotationTransform = CGAffineTransform(translationX: naturalSize.height, y: 0)
                .rotated(by: .pi/2)
            layerInstruction.setTransform(rotationTransform, at: .zero)
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            exportSession.videoComposition = videoComposition

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
    
    func sendVideo() async {
        guard let videoURL = lastRecordedVideoURL else { return }
        do {
            let mp4URL = try await convertMovToMp4(inputURL: videoURL)
            let fileId = try await AppwriteManager.shared.uploadVideo(fileURL: mp4URL)
            print("Video uploaded successfully with ID: \(fileId)")
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
        guard elapsed >= (1.0 / (desiredFrameRate * 1.1)) else { return }
        lastFrameTime = currentTime
        guard var currentFrame = sampleBuffer.cgImage else { return }
        
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
            firstHalfURL = outputFileURL
            toggleCamera()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startSecondHalfRecordingSegment()
            }
        } else {
            secondHalfURL = outputFileURL
            if let firstHalfURL = firstHalfURL,
               let secondHalfURL = secondHalfURL {
                Task {
                    await combineVideos(firstHalfURL: firstHalfURL,
                                      secondHalfURL: secondHalfURL)
                }
            }
            DispatchQueue.main.async {
                self.isRecording = false
                self.topBarProgress = 0.0
                self.recordButtonProgress = 0.0
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
