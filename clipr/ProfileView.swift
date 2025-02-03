import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var navigationState: NavigationState
    let appwrite = Appwrite()
    
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
            
            Spacer()
            
            Button(action: {
                Task {
                    do {
                        try await appwrite.onLogout()
                        await MainActor.run {
                            navigationState.isLoggedIn = false
                        }
                    } catch {
                        print("Logout error: \(error)")
                    }
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
    }
} 