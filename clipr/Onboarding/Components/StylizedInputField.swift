import SwiftUI

struct StylizedInputField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.cadetGray)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cadetGray.opacity(0.3), lineWidth: 1)
        )
    }
}

// Preview
#Preview {
    VStack(spacing: 16) {
        StylizedInputField(
            placeholder: "Full Name",
            text: .constant(""),
            systemImage: "person.fill"
        )
        StylizedInputField(
            placeholder: "Email",
            text: .constant(""),
            systemImage: "envelope.fill",
            keyboardType: .emailAddress
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
} 