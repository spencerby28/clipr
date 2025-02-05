import SwiftUI

struct OnboardingDetailsView: View {
    @StateObject private var appwrite = AppwriteManager.shared
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var profileImage: Image? = nil
    @State private var showPhotoActionSheet: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var inputImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    
    var onOnboardingComplete: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Let's Set Up Your Profile")
                .font(.largeTitle.bold())
                .foregroundColor(.outerSpace)
                .padding(.top, 20)
            
            // Profile picture selection
            VStack(spacing: 8) {
                Button(action: {
                    showPhotoActionSheet = true
                }) {
                    if let profileImage = profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cadetGray, lineWidth: 2))
                            .shadow(radius: 4)
                            .overlay(
                                Circle()
                                    .fill(Color.black.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    )
                                    .opacity(0)
                                    .frame(width: 150, height: 150)
                                    .opacity(0.7)
                                    .opacity(0)
                            )
                            .hoverEffect(.lift)
                    } else {
                        Circle()
                            .fill(Color.cadetGray.opacity(0.3))
                            .frame(width: 150, height: 150)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.cadetGray)
                                    Text("Add Photo")
                                        .font(.caption)
                                        .foregroundColor(.cadetGray)
                                }
                            )
                    }
                }
                
                if profileImage != nil {
                    Text("Looking good!")
                        .font(.subheadline)
                        .foregroundColor(.cadetGray)
                        .transition(.opacity)
                }
            }
            .confirmationDialog("Choose Photo", isPresented: $showPhotoActionSheet) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
                ImagePicker(image: $inputImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showCamera, onDismiss: loadImage) {
                ImagePicker(image: $inputImage, sourceType: .camera)
            }
            
            VStack(spacing: 16) {
                // Full Name field
                StylizedInputField(
                    placeholder: "Full Name",
                    text: $fullName,
                    systemImage: "person.fill"
                )
                
                // Username field
                HStack {
                    StylizedInputField(
                        placeholder: "Username",
                        text: $username,
                        systemImage: "at"
                    )
                    .onChange(of: username) { newValue in
                        appwrite.checkUsername(newValue)
                    }
                    
                    // Username availability indicator
                    if !username.isEmpty {
                        if appwrite.isCheckingUsername {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else if let isAvailable = appwrite.isUsernameAvailable {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isAvailable ? .green : .red)
                                .font(.system(size: 24))
                        }
                    }
                }
                
                // Email field
                StylizedInputField(
                    placeholder: "Email (Optional)",
                    text: $email,
                    systemImage: "envelope.fill"
                )
            }
            .padding(.horizontal, 20)
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Welcome button
            Button(action: {
                Task {
                    await completeOnboarding()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    Color.burntSienna
                        .opacity(isFormValid ? 1 : 0.5)
                )
                .cornerRadius(8)
                .padding(.horizontal, 20)
            }
            .disabled(!isFormValid || isLoading)
            .padding(.bottom, 20)
        }
        .background(Color.dimGray.opacity(0.1))
        .navigationBarHidden(true)
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty && 
        !username.isEmpty && 
        profileImage != nil && 
        (appwrite.isUsernameAvailable ?? false) &&
        !appwrite.isCheckingUsername
    }
    
    func loadImage() {
        if let inputImage = inputImage {
            profileImage = Image(uiImage: inputImage)
        }
    }
    
    func completeOnboarding() async {
        guard let inputImage = inputImage else { return }
        
        isLoading = true
        error = nil
        
        do {
            let account = try await appwrite.getAccount()
            _ = try await appwrite.createUserProfile(
                name: fullName,
                username: username,
                email: email.isEmpty ? nil : email,
                phoneNumber: account.phone,
                profileImage: inputImage
            )
            
            await MainActor.run {
                isLoading = false
                onOnboardingComplete?()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error.localizedDescription
            }
        }
    }
}

struct OnboardingDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingDetailsView()
    }
}
