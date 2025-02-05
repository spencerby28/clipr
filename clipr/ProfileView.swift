import SwiftUI
import AppwriteModels
import JSONCodable

struct ProfileView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var appwrite = AppwriteManager.shared
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Profile Header
            VStack(spacing: 16) {
                if let user = appwrite.currentUser {
                    if let avatarId = user.avatarId,
                       let avatarURL = appwrite.getAvatarURL(avatarId: avatarId) {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        } placeholder: {
                            ProgressView()
                                .frame(width: 100, height: 100)
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }
                    
                    Text(user.name ?? "No Name")
                        .font(.title2)
                        .bold()
                    
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ProgressView()
                        .frame(width: 100, height: 100)
                }
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
            if let user = appwrite.currentUser {
                ShareSheet(activityItems: ["Join me on Clipr! https://clipr.sb28.xyz/invite/\(user.username)"])
            }
        }
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "Unknown error occurred")
        })
        .onAppear {
            Task {
                do {
                    try await appwrite.loadCurrentUser()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
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
