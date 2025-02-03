import Foundation
import AVFoundation
import CoreImage

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
    private let totalRecordingDuration: TimeInterval = 10.0
    private let flipCameraTime: TimeInterval = 5.0
    
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
        guard await isAuthorized,
              let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: currentPosition),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { return }
        
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
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                self.recordingProgress = elapsed / self.totalRecordingDuration
                
                // Handle countdown for both segments
                if elapsed < self.flipCameraTime {
                    // First 5 seconds
                    let timeLeft = self.flipCameraTime - elapsed
                    if timeLeft <= 3 {
                        self.countdown = Int(ceil(timeLeft))
                        // Hide the countdown when it reaches 1 and we're about to flip
                        self.shouldShowCountdown = timeLeft > 0.1
                    }
                } else {
                    // Second 5 seconds
                    let timeLeft = self.totalRecordingDuration - elapsed
                    let timeInSecondHalf = elapsed - self.flipCameraTime
                    
                    if timeLeft <= 3 {
                        self.countdown = Int(ceil(timeLeft))
                        // Only show countdown after 2 seconds in the second half
                        self.shouldShowCountdown = timeInSecondHalf >= 2.0
                    }
                }
                
                // Handle camera flip at halfway point
                if elapsed >= self.flipCameraTime && elapsed < (self.flipCameraTime + 0.1) {
                    self.toggleCamera()
                }
                
                // Stop recording at max duration
                if elapsed >= self.totalRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        recordingStartTime = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingProgress = 0
            self.countdown = 0
            self.shouldShowCountdown = false
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
