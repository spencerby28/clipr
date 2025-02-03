import SwiftUI

struct CameraView: View {
    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                Button(action: {
                    // TODO: Implement camera functionality
                }) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 50)
            }
        }
    }
} 