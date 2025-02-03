import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Progress circle
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // Progress indicator
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.red, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Inner circle
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 70, height: 70)
            }
        }
    }
} 