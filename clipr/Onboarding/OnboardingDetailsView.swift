import SwiftUI

struct OnboardingDetailsView: View {
    @State private var username: String = ""
    @State private var profileImage: Image? = nil
    @State private var showImagePicker: Bool = false
    @State private var inputImage: UIImage? = nil
    @State private var isLoading: Bool = false
    
    var onOnboardingComplete: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Let's Set Up Your Profile")
                .font(.largeTitle.bold())
                .foregroundColor(.outerSpace)
                .padding(.top, 20)
            
            // Profile picture selection
            Button(action: {
                print("[OnboardingDetailsView.swift] Profile picture tapped")
                showImagePicker = true
            }) {
                if let profileImage = profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cadetGray, lineWidth: 2))
                        .shadow(radius: 4)
                } else {
                    Circle()
                        .fill(Color.cadetGray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.cadetGray)
                        )
                }
            }
            .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
                ImagePicker(image: $inputImage)
            }
            
            // Username text field
            TextField("Choose a username", text: $username)
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .foregroundColor(.black)
            
            // Welcome button (completes onboarding)
            Button(action: {
                completeOnboarding()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Welcome to Clipr")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.burntSienna)
                .cornerRadius(8)
                .padding(.horizontal, 20)
            }
            .disabled(username.isEmpty || profileImage == nil || isLoading)
            
            Spacer()
        }
        .padding()
        .background(Color.dimGray.opacity(0.1))
        .navigationTitle("Profile Setup")
        .onAppear {
            print("[OnboardingDetailsView.swift] View appeared")
        }
    }
    
    func loadImage() {
        print("[OnboardingDetailsView.swift] Image picker dismissed")
        if let inputImage = inputImage {
            profileImage = Image(uiImage: inputImage)
            print("[OnboardingDetailsView.swift] Loaded selected image")
        }
    }
    
    func completeOnboarding() {
        print("[OnboardingDetailsView.swift] Completing onboarding with username: \(username)")
        isLoading = true
        // Simulate network delay—for real use, call your API here
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            print("[OnboardingDetailsView.swift] Onboarding complete. Username: \(username)")
            onOnboardingComplete?()
        }
    }
}

struct OnboardingDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OnboardingDetailsView()
        }
    }
}