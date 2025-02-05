import SwiftUI

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cameraManager = CameraManager()
    @State private var currentFrame: CGImage?
    @State private var isProcessing = false
    
    private let cornerRadius: CGFloat = 24
    private let borderWidth: CGFloat = 3
    
    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            // Calculate height using a 16:9 aspect ratio.
            let previewHeight = viewWidth * (16.0/9.0)
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    // Camera Preview Container
                    ZStack {
                        if let image = currentFrame {
                            Image(decorative: image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: viewWidth - 32, height: previewHeight)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                .padding(borderWidth/2)
                                .overlay(
                                    ZStack {
                                        if cameraManager.isRecording {
                                            RecordingBorder(
                                                progress: cameraManager.recordButtonProgress,
                                                cornerRadius: cornerRadius
                                            )
                                            .stroke(Color.red, lineWidth: borderWidth)
                                        } else {
                                            RoundedRectangle(cornerRadius: cornerRadius)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        }
                                        
                                        if isProcessing {
                                            RoundedRectangle(cornerRadius: cornerRadius)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.black.opacity(0.3),
                                                            Color.black.opacity(0.7)
                                                        ]),
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .transition(.opacity)
                                        }
                                    }
                                    .padding(borderWidth/2)
                                )
                                .onTapGesture(count: 2) {
                                    if !cameraManager.isRecording {
                                        cameraManager.toggleCamera()
                                    }
                                }
                        } else {
                            ContentUnavailableView("No camera feed",
                                                 systemImage: "xmark.circle.fill")
                                .frame(width: viewWidth - 32, height: previewHeight)
                        }
                        
                        // Camera Controls
                        VStack {
                            HStack {
                                Spacer()
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
                            
                            // Record button
                            if !cameraManager.isRecording {
                                Button(action: {
                                    cameraManager.startRecording()
                                }) {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 70, height: 70)
                                }
                                .padding(.bottom, 40)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    Spacer()
                }
                
                // Top progress bar
                if cameraManager.isRecording {
                    GeometryReader { metrics in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: metrics.size.width * cameraManager.topBarProgress, height: 4)
                            .position(x: metrics.size.width/2, y: 2)
                    }
                }
            }
            // Countdown overlay moved to top right with a smaller font.
            .overlay(
                Group {
                    if cameraManager.shouldShowCountdown {
                        Text("\(cameraManager.countdown)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut, value: cameraManager.countdown)
                    }
                },
                alignment: .topTrailing
            )
            .onChange(of: cameraManager.isRecording) { _, isRecording in
                if !isRecording && cameraManager.recordButtonProgress >= 1.0 {
                    withAnimation {
                        isProcessing = true
                    }
                }
            }
            .task {
                // Start camera preview stream.
                for await image in cameraManager.previewStream {
                    currentFrame = image
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
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
                        withAnimation {
                            isProcessing = false
                        }
                        cameraManager.showingPreview = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            cameraManager.startRecording()
                        }
                    },
                    onSend: { progressCallback in
                        Task {
                            await cameraManager.sendVideo(progressCallback: progressCallback)
                            cameraManager.showingPreview = false
                            withAnimation {
                                isProcessing = false
                            }
                        }
                    }
                )
            }
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
