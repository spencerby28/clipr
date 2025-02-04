import SwiftUI

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cameraManager = CameraManager()
    @State private var currentFrame: CGImage?
    
    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            // Calculate height based on 16:9 aspect ratio
            let previewHeight = viewWidth * (16.0/9.0)
            
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Camera Preview Container
                    ZStack {
                        if let image = currentFrame {
                            Image(decorative: image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: viewWidth - 32, height: previewHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            ContentUnavailableView("No camera feed", 
                                                 systemImage: "xmark.circle.fill")
                                .frame(width: viewWidth - 32, height: previewHeight)
                        }
                        
                        // Overlay Controls
                        VStack {
                            HStack {
                                Spacer()
                                // Only show camera toggle when not recording
                                if !cameraManager.isRecording {
                                    Button(action: {
                                        cameraManager.toggleCamera()
                                    }) {
                                        Image(systemName: "camera.rotate.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    .padding(16)
                                }
                            }
                            
                            Spacer()
                            
                            // Record Button
                            VStack {
                                Spacer()
                                RecordButton(
                                    isRecording: cameraManager.isRecording,
                                    progress: cameraManager.recordingProgress,
                                    action: {
                                        if !cameraManager.isRecording {
                                            cameraManager.startRecording()
                                        }
                                        // Remove stop recording action since it's handled automatically
                                    }
                                )
                                .disabled(cameraManager.isRecording) // Disable during recording
                                .padding(.bottom, 30)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
                
                // Countdown overlay
                if cameraManager.shouldShowCountdown {
                    Text("\(cameraManager.countdown)")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut, value: cameraManager.countdown)
                }
                
                // Optional: Add a progress indicator at the top
                GeometryReader { metrics in
                    if cameraManager.isRecording {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: metrics.size.width * CGFloat(cameraManager.recordingProgress),
                                   height: 4)
                            .position(x: metrics.size.width/2, y: 2)
                    }
                }
            }
            .task {
                // Start camera preview stream
                for await image in cameraManager.previewStream {
                    currentFrame = image
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    print("Scene became active")
                    cameraManager.startSession()
                case .inactive, .background:
                    print("Scene became inactive/background")
                    if !cameraManager.isRecording {
                        cameraManager.stopSession()
                    }
                @unknown default:
                    break
                }
            }
            .onAppear {
                print("CameraView appeared")
                print("Screen dimensions:")
                print("- Width: \(viewWidth)")
                print("- Preview height: \(previewHeight)")
                print("- Aspect ratio: \(viewWidth/previewHeight)")
                cameraManager.startSession()
            }
            .onDisappear {
                print("CameraView disappeared")
                if !cameraManager.isRecording {
                    cameraManager.stopSession()
                }
            }
        }
        .fullScreenCover(isPresented: $cameraManager.showingPreview) {
            if let videoURL = cameraManager.lastRecordedVideoURL {
                VideoPreviewView(
                    videoURL: videoURL,
                    onRetake: {
                        cameraManager.showingPreview = false
                        // Add delay to allow dismissal animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            cameraManager.startRecording()
                        }
                    },
                    onSend: {
                        Task {
                            await cameraManager.sendVideo()
                            cameraManager.showingPreview = false
                        }
                    }
                )
            }
        }
    }
}

// Preview provider
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
} 
