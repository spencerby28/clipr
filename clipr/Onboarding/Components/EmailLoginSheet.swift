import SwiftUI

struct EmailLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appwrite = AppwriteManager.shared
    @State private var email: String = "demo@sb28.xyz"
    @State private var password: String = "demodemo"
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
            
            BackgroundBlurView()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Apple Demo Account")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                        HapticManager.shared.lightImpact()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                
                Text("This login is only available for Apple App Store review purposes.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    StylizedInputField(
                        placeholder: "Email",
                        text: $email,
                        systemImage: "envelope.fill",
                        keyboardType: .emailAddress
                    )
                    
                    StylizedInputField(
                        placeholder: "Password",
                        text: $password,
                        systemImage: "lock.fill"
                    )
                }
                .padding(.horizontal)
                
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.burntSienna)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isLoading)
            }
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .preferredColorScheme(.light)
    }
    
    private func login() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await appwrite.login(email: email, password: password)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    EmailLoginSheet()
}