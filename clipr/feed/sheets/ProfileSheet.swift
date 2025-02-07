//
//  ProfileSheet.swift
//  clipr
//
//  Created by Spencer Byrne on 2/7/25.
//

import Foundation
import SwiftUI
import Kingfisher

struct ProfileSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var appwrite = AppwriteManager.shared
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Add a clear color view to block touches
            Color.black.opacity(0.001)
                .ignoresSafeArea()
            
            BackgroundBlurView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            if let user = appwrite.currentUser {
                                if let avatarId = user.avatarId,
                                   let avatarURL = appwrite.getAvatarURL(avatarId: avatarId) {
                                    KFImage(avatarURL)
                                        .placeholder {
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 100, height: 100)
                                        }
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.2), radius: 10)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(user.name ?? "No Name")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                                
                                if let username = user.username {
                                    Text("@\(username)")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            } else {
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            }
                        }
                        .padding(.top, 12)
                        
                        // Settings Section
                        VStack(spacing: 16) {
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.white)
                                    Text("Invite Friends")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                // Navigate to settings
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                        .foregroundColor(.white)
                                    Text("Settings")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 32)
                        
                        Button(action: {
                            Task {
                                try? await appwrite.logout()
                                isPresented = false
                            }
                        }) {
                            Text("Logout")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .background(.clear)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingShareSheet) {
            if let user = appwrite.currentUser {
                ShareSheet(activityItems: ["Join me on Clipr! https://clipr.sb28.xyz/invite/\(user.username!)"])
            }
        }
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "Unknown error occurred")
        })
        .task {
            do {
                try await appwrite.loadCurrentUser()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ProfileSheet(isPresented: .constant(true))
}
