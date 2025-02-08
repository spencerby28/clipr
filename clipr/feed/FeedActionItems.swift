//
//  FeedActionItems.swift
//  clipr
//
//  Created by Spencer Byrne on 2/6/25.
//

import SwiftUI

struct FeedActionItems: View {
    @Binding var showSettingsSheet: Bool
    @Binding var showProfileSheet: Bool
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack {
            // Left menu button: icon then text "Friends" with smaller icon
            Button(action: {
                showSettingsSheet.toggle()
                isExpanded = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .clipShape(Circle())
                    
                    Text("friends")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 1)
                .background {
                    Capsule()
                        .fill(.thinMaterial)
                        .preferredColorScheme(.dark)
                        .opacity(0.7)
                }
            }
            
            Spacer()
            
            // Right profile button: text then image "Profile" with smaller icon
            Button(action: {
                showProfileSheet.toggle()
                isExpanded = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .clipShape(Circle())
                    
                    Text("profile")
                        .fontWeight(.semibold)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 1)
                .background {
                    Capsule()
                        .fill(.thinMaterial)
                        .opacity(0.7)
                        .preferredColorScheme(.dark)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}

#Preview {
    ZStack {
        // Test with different background colors
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        
        FeedActionItems(showSettingsSheet: .constant(false), 
                       showProfileSheet: .constant(false), 
                       isExpanded: .constant(false))
    }
}

