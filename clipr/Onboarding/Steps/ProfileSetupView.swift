import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject private var state: OnboardingState
    @State private var photoItem: PhotosPickerItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up your")
                    .font(.title.weight(.medium))
                    .foregroundColor(.outerSpace)
                Text("profile")
                    .font(.title.weight(.bold))
                    .foregroundColor(.outerSpace)
            }
            .padding(.horizontal, 24)
            
            // Profile Photo
            VStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    if let image = state.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.burntSienna, lineWidth: 3)
                            )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.burntSienna)
                            )
                    }
                }
                
                Text("Add Profile Photo")
                    .font(.subheadline)
                    .foregroundColor(.burntSienna)
            }
            .frame(maxWidth: .infinity)
            
            // Username Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                StylizedInputField(
                    placeholder: "@username",
                    text: $state.username
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Complete Button
            Button(action: completeSetup) {
                Text("Complete Setup")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.burntSienna)
                    )
                    .shadow(
                        color: Color.burntSienna.opacity(0.3),
                        radius: 8, x: 0, y: 4
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .onChange(of: photoItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        state.profileImage = image
                    }
                }
            }
        }
        .overlay(
            Group {
                if state.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        )
                }
            }
        )
    }
    
    private func completeSetup() {
        guard !state.username.isEmpty else {
            // Show error for empty username
            state.error = NSError(
                domain: "ProfileSetup",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Please enter a username"]
            )
            return
        }
        
        state.isLoading = true
        // TODO: Implement profile setup
        // For now, just simulate the process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            state.isLoading = false
            state.advance()
        }
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(OnboardingState())
} 