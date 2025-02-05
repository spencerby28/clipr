import SwiftUI

struct StylizedInputField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cadetGray.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, 24)
    }
}

// Preview
#Preview {
    VStack {
        StylizedInputField(placeholder: "Enter phone number", text: .constant(""))
            .padding()
    }
} 