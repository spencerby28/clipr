import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    
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
                        if let image = viewModel.currentFrame {
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
                                // Camera Toggle Button
                                Button(action: {
                                    Task {
                                        await viewModel.toggleCamera()
                                    }
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
                            
                            Spacer()
                            
                            // Record Button
                            Button(action: {
                                viewModel.toggleRecording()
                            }) {
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : Color.white)
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                    )
                            }
                            .padding(.bottom, 24)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
            }
            .onAppear {
                print("Screen dimensions:")
                print("- Width: \(viewWidth)")
                print("- Preview height: \(previewHeight)")
                print("- Aspect ratio: \(viewWidth/previewHeight)")
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