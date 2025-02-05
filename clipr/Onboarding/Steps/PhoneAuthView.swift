import SwiftUI

struct PhoneAuthView: View {
    @EnvironmentObject private var state: OnboardingState
    @State private var isVerifying: Bool = false
    @State private var verificationCode: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if !isVerifying {
                // Phone Number Entry
                PhoneEntryView(
                    phoneNumber: $state.phoneNumber,
                    onSubmit: startVerification
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your")
                            .font(.title.weight(.medium))
                            .foregroundColor(.outerSpace)
                        Text("phone number?")
                            .font(.title.weight(.bold))
                            .foregroundColor(.outerSpace)
                    }
                }
            } else {
                // Verification Code Entry
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter the code")
                            .font(.title.weight(.medium))
                            .foregroundColor(.outerSpace)
                        Text("sent to \(state.phoneNumber)")
                            .font(.title3)
                            .foregroundColor(.cadetGray)
                    }
                    .padding(.horizontal, 24)
                    
                    // Code Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verification Code")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                        
                        StylizedInputField(
                            placeholder: "123456",
                            text: $verificationCode,
                            keyboardType: .numberPad
                        )
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Verify Button
                    Button(action: verifyCode) {
                        Text("Verify")
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
                    
                    // Resend Code Button
                    Button(action: resendCode) {
                        Text("Resend Code")
                            .font(.subheadline)
                            .foregroundColor(.burntSienna)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
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
        .alert("Error", isPresented: .constant(state.error != nil)) {
            Button("OK") {
                state.error = nil
            }
        } message: {
            if let error = state.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func startVerification() {
        state.isLoading = true
        // TODO: Implement phone verification
        // For now, just simulate the process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            state.isLoading = false
            withAnimation {
                isVerifying = true
            }
        }
    }
    
    private func verifyCode() {
        state.isLoading = true
        // TODO: Implement code verification
        // For now, just simulate the process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            state.isLoading = false
            state.advance()
        }
    }
    
    private func resendCode() {
        state.isLoading = true
        // TODO: Implement resend code
        // For now, just simulate the process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            state.isLoading = false
        }
    }
}

#Preview {
    PhoneAuthView()
        .environmentObject(OnboardingState())
} 