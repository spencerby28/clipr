import SwiftUI
import Appwrite

struct OnboardingPhoneAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationState: NavigationState
    @StateObject private var appwrite = AppwriteManager.shared
    @State private var phoneNumber: String = ""
    @State private var formattedPhoneNumber: String = ""
    @State private var otpText: String = ""
    @State private var userId: String = ""
    @State private var secret: String = ""
    @State private var isLoading: Bool = false
    @State private var isVerifying: Bool = false
    @State private var isVerified: Bool = false
    @State private var errorMessage: String = ""
    @State private var showEmailLogin: Bool = false
    @FocusState private var isKeyboardShowing: Bool
    
    var onVerificationComplete: (() -> Void)?
    
    private var isValidPhoneNumber: Bool {
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        return digitsOnly.count == 10
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.filter { $0.isNumber }
        guard !cleaned.isEmpty else { return "" }
        
        var result = "("
        
        for (index, char) in cleaned.prefix(10).enumerated() {
            if index == 3 {
                result += ") "
            } else if index == 6 {
                result += "-"
            }
            result.append(char)
        }
        return result
    }
    
    private func unformatPhoneNumber(_ formatted: String) -> String {
        return formatted.filter { $0.isNumber }
    }
    
    private func handlePhoneInput(_ newValue: String) -> String {
        // If deleting, remove formatting first
        if newValue.count < formattedPhoneNumber.count {
            let unformatted = unformatPhoneNumber(formattedPhoneNumber)
            var newUnformatted = unformatted
            if !newUnformatted.isEmpty {
                newUnformatted.removeLast()
            }
            phoneNumber = newUnformatted
            return formatPhoneNumber(newUnformatted)
        }
        
        // If adding, just format the numbers
        let numbers = newValue.filter { $0.isNumber }
        phoneNumber = numbers
        return formatPhoneNumber(numbers)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height * 0.1)
                
                // Header Section
                VStack(spacing: 8) {
                    Text("Welcome to clipr")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.outerSpace)
                    
                    Text("Let's verify your phone number to get started")
                        .font(.body)
                        .foregroundColor(.cadetGray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .onLongPressGesture {
                    showEmailLogin = true
                    HapticManager.shared.mediumImpact()
                }
                
                Spacer()
                    .frame(height: 24)
                
                // Main Content Section
                VStack(spacing: 32) {
                    if userId.isEmpty {
                        // Phone Input Section
                        HStack(spacing: 12) {
                            // Country code section
                            HStack(spacing: 4) {
                                Text("🇺🇸")
                                    .font(.title2)
                                Text("+1")
                                    .foregroundColor(.outerSpace)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(height: 52)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            
                            TextField("", text: $formattedPhoneNumber)
                                .keyboardType(.numberPad)
                                .foregroundColor(.outerSpace)
                                .textContentType(.telephoneNumber)
                                .font(.system(size: 17))
                                .frame(height: 52)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                )
                                .shadow(color: Color.burntSienna.opacity(0.2), radius: 8, x: 0, y: 4)
                                .frame(maxWidth: .infinity)
                                .focused($isKeyboardShowing)
                                .onChange(of: formattedPhoneNumber) { newValue in
                                    formattedPhoneNumber = handlePhoneInput(newValue)
                                    
                                    if phoneNumber.count == 10 {
                                        isKeyboardShowing = false
                                    }
                                }
                                .placeholder(when: formattedPhoneNumber.isEmpty) {
                                    Text("(555) 555-5555")
                                        .foregroundColor(.outerSpace.opacity(0.5))
                                        .padding(.leading, 10)
                                }
                        }
                        .padding(.horizontal, 24)
                    } else {
                        // Phone Number Display
                        VStack(spacing: 8) {
                            Text("Sent to")
                                .font(.subheadline)
                                .foregroundColor(.cadetGray)
                            Text(formattedPhoneNumber)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.outerSpace)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // OTP Section
                    if !userId.isEmpty {
                        VStack(spacing: 24) {
                            Text("Enter Verification Code")
                                .font(.headline)
                                .foregroundColor(.outerSpace)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { index in
                                    OTPTextBox(index)
                                }
                            }
                            .background(
                                TextField("", text: $otpText.limit(4))
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .frame(width: 1, height: 1)
                                    .opacity(0.001)
                                    .focused($isKeyboardShowing)
                            )
                            
                            if isVerifying {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.burntSienna)
                            }
                        }
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isKeyboardShowing = true
                            }
                        }
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .padding(.horizontal, 24)
                    }
                    
                    // Continue Button
                    if userId.isEmpty {
                        Button(action: initializeAuth) {
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
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.burntSienna)
                                    .opacity(isValidPhoneNumber ? 1 : 0.5)
                            )
                            .padding(.horizontal, 24)
                        }
                        .disabled(isLoading || !isValidPhoneNumber)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.init(hex: "#FFF8F0"))
        }
        .onChange(of: otpText) { newValue in
            if newValue.count == 4 {
                verifyOTP()
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginSheet()
        }
        .onChange(of: appwrite.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    do {
                        try await appwrite.loadCurrentUser()
                        await MainActor.run {
                            navigationState.isLoggedIn = true
                            navigationState.hasSeenOnboarding = true
                            dismiss()
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // A simple view for each OTP number box
    @ViewBuilder
    func OTPTextBox(_ index: Int) -> some View {
        ZStack {
            if otpText.count > index {
                let startIndex = otpText.startIndex
                let charIndex = otpText.index(startIndex, offsetBy: index)
                let charToString = String(otpText[charIndex])
                Text(charToString)
                    .font(.title)
                    .foregroundColor(.outerSpace)
            } else {
                Text(" ")
                    .font(.title)
                    .foregroundColor(.cadetGray)
            }
        }
        .frame(width: 45, height: 45)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke((isKeyboardShowing && otpText.count == index) ? Color.burntSienna : Color.cadetGray.opacity(0.3),
                        lineWidth: (isKeyboardShowing && otpText.count == index) ? 1.5 : 0.5)
                .animation(.easeInOut(duration: 0.2), value: isKeyboardShowing)
        )
    }
    
    // Initialize phone auth via API call
    private func initializeAuth() {
        print("[OnboardingPhoneAuthView.swift] Initializing auth for phone number: \(phoneNumber)")
        isLoading = true
        errorMessage = ""
        guard let url = URL(string: "https://sms.clipr.vip/auth/phone/init?phone_number=\(phoneNumber)") else {
            errorMessage = "Invalid URL"
            isLoading = false
            print("[OnboardingPhoneAuthView.swift] Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("[OnboardingPhoneAuthView.swift] Init error: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data received"
                    print("[OnboardingPhoneAuthView.swift] No data received")
                    return
                }
                print("[OnboardingPhoneAuthView.swift] Received init response: \(String(data: data, encoding: .utf8) ?? "")")
                do {
                    let response = try JSONDecoder().decode(InitResponse.self, from: data)
                    self.userId = response.userId
                    self.secret = response.secret
                    print("[OnboardingPhoneAuthView.swift] Auth initialized successfully. UserID: \(response.userId)")
                    self.isKeyboardShowing = true
                } catch {
                    self.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    print("[OnboardingPhoneAuthView.swift] Decoding error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // Verify the OTP received from the user
    private func verifyOTP() {
        print("[OnboardingPhoneAuthView.swift] Verifying OTP: \(otpText)")
        isVerifying = true
        errorMessage = ""
        isKeyboardShowing = false // Dismiss keyboard immediately
        
        guard let url = URL(string: "https://sms.clipr.vip/auth/phone/verify") else {
            errorMessage = "Invalid URL"
            isVerifying = false
            print("[OnboardingPhoneAuthView.swift] Invalid verify URL")
            return
        }
        let payload = VerifyPayload(user_id: userId, secret: secret, otp_code: otpText, phone_number: phoneNumber)
        print("[OnboardingPhoneAuthView.swift] Verify payload: \(payload)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            errorMessage = "Failed to encode payload"
            isVerifying = false
            print("[OnboardingPhoneAuthView.swift] Payload encoding error: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isVerifying = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("[OnboardingPhoneAuthView.swift] Verification error: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data received"
                    print("[OnboardingPhoneAuthView.swift] No data received during verification")
                    return
                }
                print("[OnboardingPhoneAuthView.swift] Received verify response: \(String(data: data, encoding: .utf8) ?? "")")
                do {
                    let response = try JSONDecoder().decode(VerifyResponse.self, from: data)
                    if response.status == "success" {
                        self.isVerified = true
                        print("[OnboardingPhoneAuthView.swift] Verification succeeded")
                        withAnimation {
                            createAppwriteSession()
                        }
                    } else {
                        self.errorMessage = "Verification failed"
                        print("[OnboardingPhoneAuthView.swift] Verification failed with status: \(response.status)")
                    }
                } catch {
                    self.errorMessage = "Failed to decode verification response: \(error.localizedDescription)"
                    print("[OnboardingPhoneAuthView.swift] Decoding verify response error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func createAppwriteSession() {
        Task {
            do {
                try await AppwriteManager.shared.onPhoneLogin(userId: userId, secret: secret, phoneNumber: phoneNumber)
                print("✅ Appwrite session created successfully")
                
                // Try to load the current user profile
                do {
                    try await AppwriteManager.shared.loadCurrentUser()
                    // If we get here, user profile exists - skip onboarding
                    await MainActor.run {
                        navigationState.isLoggedIn = true
                        navigationState.hasSeenOnboarding = true
                        dismiss()
                    }
                } catch {
                    // No user profile exists - continue with onboarding
                    await MainActor.run {
                        onVerificationComplete?()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create session: \(error.localizedDescription)"
                    print("❌ Appwrite Session Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: Response Models

struct InitResponse: Codable {
    let status: String
    let message: String
    let userId: String
    let secret: String
}

struct VerifyPayload: Codable {
    let user_id: String
    let secret: String
    let otp_code: String
    let phone_number: String
}

struct VerifyResponse: Codable {
    let status: String
}

extension Binding where Value == String {
    func limit(_ length: Int) -> Self {
        if self.wrappedValue.count > length {
            DispatchQueue.main.async {
                self.wrappedValue = String(self.wrappedValue.prefix(length))
            }
        }
        return self
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct OnboardingPhoneAuthView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OnboardingPhoneAuthView()
        }
    }
}
