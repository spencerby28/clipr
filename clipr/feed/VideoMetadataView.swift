//
//  VideoMetadataView.swift
//  clipr
//
//  Created by Spencer Byrne on 2/5/25.
//

import SwiftUI


struct VideoMetadataView: View {
    let video: Video
    let user: UserProfile
    @State private var isLiked = false
    @State private var likeCount: Int
    
    init(video: Video, user: UserProfile) {
        self.video = video
        self.user = user
        _likeCount = State(initialValue: video.likeCount)
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom metadata bar
            HStack(alignment: .center, spacing: 16) {
                // Left side - Profile pic and info
                HStack(alignment: .center, spacing: 12) {
                    // Profile pic
                    if let avatarId = user.avatarId,
                       let avatarURL = AppwriteManager.shared.getAvatarURL(avatarId: avatarId) {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 50, height: 50)
                    }
                    
                    // User info and caption stack
                    VStack(alignment: .leading, spacing: 1) {
                        // Username and time
                        Text("@\(user.username ?? "unknown")")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(video.timeAgo)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if let caption = video.caption {
                            Text(caption)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side - Stats
                VStack(alignment: .center, spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLiked.toggle()
                            likeCount += isLiked ? 1 : -1
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(isLiked ? .red : .white)
                                .scaleEffect(isLiked ? 1.1 : 1.0)
                            Text("\(likeCount)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(StatButtonStyle())
                    
                    Button(action: {
                        // Handle comment action
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.right.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("\(video.commentCount)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(StatButtonStyle())
                }
                .frame(width: 44)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 44)
            .padding(.top, 8)
        }
    }
}

struct StatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())  // Makes entire area tappable
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
