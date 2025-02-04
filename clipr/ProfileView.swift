import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                
            
            Spacer()
            
            Button(action: {
                Task {
                    await navigationState.signOut()
                }
            }) {
                Text("Logout")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .onAppear {
            cameraManager.loadSavedVideos()
        }
    }
} 
