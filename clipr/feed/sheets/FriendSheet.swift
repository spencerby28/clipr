//
//  FriendSheet.swift
//  clipr
//
//  Created by Spencer Byrne on 2/7/25.
//

import Foundation
import SwiftUI
import Kingfisher
import UIKit

struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct FriendSheet: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var users: [UserProfile] = []
    @State private var isLoading = true
    @State private var error: String?
    
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
                    Text("Friends")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                        HapticManager.shared.lightImpact()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search friends", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Friends list
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Spacer()
                } else if let errorMessage = error {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                        Button("Retry") {
                            Task {
                                await loadUsers()
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredUsers, id: \.id) { user in
                                UserRow(user: user)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .contentShape(Rectangle())  // Ensure the entire ZStack captures touches
        .background(.clear)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .preferredColorScheme(.dark)
        .task {
            await loadUsers()
        }
    }
    
    private var filteredUsers: [UserProfile] {
        guard !searchText.isEmpty else { return users }
        return users.filter {
            $0.name?.localizedCaseInsensitiveContains(searchText) == true ||
            $0.username?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        error = nil
        
        do {
            let documents = try await AppwriteManager.shared.appwrite.databases.listDocuments(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.usersCollectionId
            )
            
            let loadedUsers: [UserProfile] = try documents.documents.compactMap { document in
                // Skip if this is the current user
                if document.data["userId"]?.value as? String == AppwriteManager.shared.currentUser?.userId {
                    return nil
                }
                
                var documentDict: [String: Any] = [
                    "id": document.id,
                    "collectionId": document.collectionId,
                    "databaseId": document.databaseId,
                    "createdAt": document.createdAt,
                    "updatedAt": document.updatedAt,
                    "permissions": document.permissions
                ]
                
                // Add user-specific fields
                if let userId = document.data["userId"]?.value as? String {
                    documentDict["userId"] = userId
                }
                if let username = document.data["username"]?.value as? String {
                    documentDict["username"] = username
                }
                if let name = document.data["name"]?.value as? String {
                    documentDict["name"] = name
                }
                if let phone = document.data["phone"]?.value as? String {
                    documentDict["phone"] = phone
                }
                if let avatarId = document.data["avatarId"]?.value as? String {
                    documentDict["avatarId"] = avatarId
                }
                if let email = document.data["email"]?.value as? String {
                    documentDict["email"] = email
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: documentDict)
                return try JSONDecoder().decode(UserProfile.self, from: jsonData)
            }
            
            await MainActor.run {
                self.users = loadedUsers
                self.isLoading = false
            }
        } catch {
            print("Error loading users: \(error)")
            await MainActor.run {
                self.error = "Failed to load users. Please try again."
                self.isLoading = false
            }
        }
    }
}

// User Row Component
struct UserRow: View {
    let user: UserProfile
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarId = user.avatarId,
               let avatarURL = AppwriteManager.shared.getAvatarURL(avatarId: avatarId) {
                KFImage(avatarURL)
                    .placeholder {
                        Circle()
                            .fill(Color.gray)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("@\(user.username ?? "unknown")")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Gauntlet AI button
            Button(action: {
                // Add gauntlet AI action
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text("Gauntlet AI")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 1)
                )
            }
        }
    }
}

#Preview {
    FriendSheet(isPresented: .constant(true))
}
