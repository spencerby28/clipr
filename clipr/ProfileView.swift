import SwiftUI
import AppwriteModels
import JSONCodable

struct ProfileView: View {
    @EnvironmentObject var navigationState: NavigationState
    @State private var username: String = "Username"
    @State private var showingShareSheet = false
    @State private var userDetails: User<[String: AnyCodable]>?
    @State private var errorMessage: String?
    @State private var showError = false
    
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
            if let user = userDetails {
                ShareSheet(activityItems: ["Join me on the app! https://yourapp.com/invite/\(user.id)"])
            } else {
                ShareSheet(activityItems: ["Join me on the app! https://yourapp.com/invite"])
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
                    _ = try await AppwriteManager.shared.getAccount()
                } catch {
                    print("❌ Profile - Error loading initial user details: \(error)")
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
