import Foundation
import AVFoundation
import CoreImage

class CameraManager: NSObject {
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
    }
    
    private func setupSession() {
        Task {
            await configureSession()
            await startSession()
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
    
    private func startSession() {
        isCancelled = false
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }
    
    private func stopSession() {
        isCancelled = true
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    func toggleCamera() {
        sessionQueue.async {
            self.currentPosition = self.currentPosition == .front ? .back : .front
            Task {
                await self.configureSession()
                await self.startSession()
            }
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
