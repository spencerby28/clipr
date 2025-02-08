import SwiftUI

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var navigationState: NavigationState
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
                        if isProcessing {
                            RecordingProcessingView(cornerRadius: cornerRadius)
                                .frame(width: viewWidth - 32, height: previewHeight)
                                .transition(.opacity)
                        } else if let image = currentFrame {
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
                        if !isProcessing {
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
                                        .padding(12)
                                        .padding(.vertical, 20)
                                    }
                                }
                                Spacer()
                                
                                // Record button
                                if !cameraManager.isRecording {
                                    Button(action: {
                                        cameraManager.startRecording()
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(.thinMaterial)
                                                .preferredColorScheme(.dark)
                                                .frame(width: 70, height: 70)
                                            
                      
                                            Image(systemName: "record.circle")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.bottom, 40)
                                }
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
            // Countdown overlay
            .overlay(
                Group {
                    if cameraManager.shouldShowCountdown {
                        Text("\(cameraManager.countdown)")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 100)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut, value: cameraManager.countdown)
                    }
                },
                alignment: .top
            )
            .onChange(of: cameraManager.isRecording) { _, isRecording in
                if !isRecording && cameraManager.recordButtonProgress >= 1.0 {
                    withAnimation {
                        isProcessing = true
                    }
                }
            }
            .onAppear {
                cameraManager.onVideoProcessingStateChanged = { processing in
                    withAnimation {
                        isProcessing = processing
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
            .statusBar(hidden: true)
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
                .environmentObject(navigationState)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CameraView()
            .preferredColorScheme(.dark)
    }
}

struct CameraPreviewContainer: View {
    let viewWidth: CGFloat
    let previewHeight: CGFloat
    let showRecordButton: Bool
    let isRecording: Bool
    let isProcessing: Bool
    let showCountdown: Bool
    let countdown: Int
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                // Camera Preview Container
                ZStack {
                    if isProcessing {
                        RecordingProcessingView(cornerRadius: 24)
                            .frame(width: viewWidth - 32, height: previewHeight)
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: viewWidth - 32, height: previewHeight)
                            .overlay(
                                ZStack {
                                    if isRecording {
                                        RecordingBorder(
                                            progress: 0.5,
                                            cornerRadius: 24
                                        )
                                        .stroke(Color.red, lineWidth: 3)
                                    } else {
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    }
                                }
                                .padding(3/2)
                            )
                        
                        // Camera Controls
                        if !isProcessing {
                            VStack {
                                HStack {
                                    Spacer()
                                    if !isRecording {
                                        Button(action: {}) {
                                            Image(systemName: "camera.rotate.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                                .padding(12)
                                                .background(Color.black.opacity(0.5))
                                                .clipShape(Circle())
                                        }
                                        .padding(12)
                                        .padding(.vertical, 20)
                                    }
                                }
                                Spacer()
                                
                                if showRecordButton && !isRecording {
                                    Button(action: {}) {
                                        ZStack {
                                            Circle()
                                                .fill(.thinMaterial)
                                                .preferredColorScheme(.dark)
                                                .frame(width: 70, height: 70)
                                            
                      
                                            Image(systemName: "record.circle")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.bottom, 40)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            
            // Top progress bar
            if isRecording {
                GeometryReader { metrics in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: metrics.size.width * 0.5, height: 4)
                        .position(x: metrics.size.width/2, y: 2)
                }
            }
            
            if showCountdown {
                Text("\(countdown)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 100)
            }
        }
        .statusBar(hidden: true)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Initial state
            GeometryReader { geometry in
                CameraPreviewContainer(
                    viewWidth: geometry.size.width,
                    previewHeight: geometry.size.width * (16.0/9.0),
                    showRecordButton: true,
                    isRecording: false,
                    isProcessing: false,
                    showCountdown: false,
                    countdown: 0
                )
            }
            .previewDisplayName("Initial State")
            
            // Recording state with countdown
            GeometryReader { geometry in
                CameraPreviewContainer(
                    viewWidth: geometry.size.width,
                    previewHeight: geometry.size.width * (16.0/9.0),
                    showRecordButton: false,
                    isRecording: true,
                    isProcessing: false,
                    showCountdown: true,
                    countdown: 3
                )
            }
            .previewDisplayName("Recording with Countdown")
            
            // Processing state
            GeometryReader { geometry in
                CameraPreviewContainer(
                    viewWidth: geometry.size.width,
                    previewHeight: geometry.size.width * (16.0/9.0),
                    showRecordButton: false,
                    isRecording: false,
                    isProcessing: true,
                    showCountdown: false,
                    countdown: 0
                )
            }
            .previewDisplayName("Processing")
        }
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
