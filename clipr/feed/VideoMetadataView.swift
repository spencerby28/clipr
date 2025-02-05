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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            
            // Creator info
            HStack {
                // Profile picture placeholder
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text(user.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(video.timeAgo)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Caption
            if let caption = video.caption {
                Text(caption)
                    .foregroundColor(.white)
                    .font(.body)
            }
            
            // Engagement stats
            HStack(spacing: 20) {
                StatView(count: video.likeCount, image: "heart.fill")
                StatView(count: video.commentCount, image: "bubble.right.fill")
            //    StatView(count: video.shareCount, image: "square.and.arrow.up.fill")
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct StatView: View {
    let count: Int
    let image: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: image)
                .foregroundColor(.white)
            Text("\(count)")
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }
}
