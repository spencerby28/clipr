import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var cameraManager = CameraManager()
    @State private var username: String = "Username"
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Profile Header
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                
                TextField("Username", text: $username)
                    .font(.title2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            
            // Settings Section
            VStack(spacing: 16) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Invite Friends")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                NavigationLink(destination: Text("Settings")) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
            }
            .padding(.horizontal)
            
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
                    .cornerRadius(12)
            }
            .padding()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: ["Join me on the app! https://yourapp.com/invite"])
        }
        .onAppear {
            cameraManager.loadSavedVideos()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ProfileView()
}
