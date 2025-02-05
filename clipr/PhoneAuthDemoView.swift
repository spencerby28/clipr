import SwiftUI
import Appwrite

struct PhoneAuthDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = "7076967865"
    @State private var otpText: String = ""
    @State private var userId = ""
    @State private var secret = ""
    @State private var isLoading = false
    @State private var isVerifying = false
    @State private var isVerified = false
    @State private var errorMessage = ""
    @FocusState private var isKeyboardShowing: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Phone Number Field
            HStack {
                Text("+1")
                    .foregroundColor(.gray)
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.numberPad)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Button("Send Code") {
                initializeAuth()
            }
            .disabled(isLoading)
            
            // OTP Section
            VStack(spacing: 12) {
                Text("Enter Verification Code")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { index in
                        OTPTextBox(index)
                    }
                }
                .background(content: {
                    TextField("", text: $otpText.limit(4))
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .frame(width: 1, height: 1)
                        .opacity(0.001)
                        .blendMode(.screen)
                        .focused($isKeyboardShowing)
                        .onChange(of: otpText) { newValue in
                            if newValue.count == 4 {
                                verifyOTP()
                            }
                        }
                })
                .contentShape(Rectangle())
                .onTapGesture {
                    isKeyboardShowing.toggle()
                }
                .overlay {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground).opacity(0.8))
                    }
                }
            }
            .padding(.vertical)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button(action: {
                if isVerified {
                    // Handle post-verification action
                } else {
                    verifyOTP()
                }
            }) {
                HStack {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isVerified ? "Verified ✓" : "Verify")
                    }
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isVerified ? Color.green : Color.blue)
                }
            }
            .disabled(otpText.count < 4 || isVerifying)
            .opacity((otpText.count < 4 || isVerifying) ? 0.6 : 1)
            .animation(.easeInOut, value: isVerified)
        }
        .padding()
        .navigationTitle("Debug Auth")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    isKeyboardShowing.toggle()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    @ViewBuilder
    func OTPTextBox(_ index: Int) -> some View {
        ZStack {
            if otpText.count > index {
                let startIndex = otpText.startIndex
                let charIndex = otpText.index(startIndex, offsetBy: index)
                let charToString = String(otpText[charIndex])
                Text(charToString)
            } else {
                Text(" ")
            }
        }
        .frame(width: 45, height: 45)
        .background {
            let status = (isKeyboardShowing && otpText.count == index)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(status ? Color.primary : Color.gray, lineWidth: status ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.2), value: isKeyboardShowing)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func initializeAuth() {
        isLoading = true
        errorMessage = ""
        
        guard let url = URL(string: "https://py-server.hotshotdev.com/auth/phone/init?phone_number=\(phoneNumber)") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        print("🔍 Initializing auth with URL: \(url)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    print("❌ Init Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    print("❌ Init Error: No data received")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Init Response: \(responseString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(InitResponse.self, from: data)
                    self.userId = response.userId // Changed from user_id to match API response
                    self.secret = response.secret
                    print("✅ Init Success - User ID: \(response.userId)")
                    isKeyboardShowing = true
                } catch {
                    errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    print("❌ Init Decode Error: \(error)")
                }
            }
        }.resume()
    }
    
    private func verifyOTP() {
        isVerifying = true
        errorMessage = ""
        
        guard let url = URL(string: "https://py-server.hotshotdev.com/auth/phone/verify") else {
            errorMessage = "Invalid URL"
            isVerifying = false
            return
        }
        
        let payload = VerifyPayload(
            user_id: userId,
            secret: secret,
            otp_code: otpText,
            phone_number: phoneNumber
        )
        
        print("📤 Verify Payload: \(payload)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            errorMessage = "Failed to encode payload"
            print("❌ Verify Encode Error: \(error.localizedDescription)")
            isVerifying = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isVerifying = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    print("❌ Verify Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    print("❌ Verify Error: No data received")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Verify Response: \(responseString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(VerifyResponse.self, from: data)
                    if response.status == "success" {
                        print("✅ Verification Success")
                        isVerified = true
                        withAnimation {
                            createAppwriteSession()
                        }
                    } else {
                        errorMessage = "Verification failed"
                        print("❌ Verification Failed")
                    }
                } catch {
                    errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    print("❌ Verify Decode Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func createAppwriteSession() {
        Task {
            do {
                try await AppwriteManager.shared.onPhoneLogin(userId: userId, secret: secret)
                print("✅ Appwrite session created successfully")
                await MainActor.run {
                    dismiss()
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

// Response models
struct InitResponse: Codable {
    let status: String
    let message: String
    let userId: String
    let secret: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case userId = "userId"
        case secret
    }
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

// MARK: View Extensions
extension View {
    func disableWithOpacity(_ condition: Bool) -> some View {
        self
            .disabled(condition)
            .opacity(condition ? 0.6 : 1)
    }
}

// MARK: Binding <String> Extension
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

#Preview {
    PhoneAuthDemoView()
} 