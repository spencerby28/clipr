//
//  VideoSchema.swift
//  clipr
//
//  Created by Spencer Byrne on 2/5/25.
//

import Foundation

struct Like: Codable {
    let id: String
    let collectionId: String
    let databaseId: String
    let createdAt: String
    let updatedAt: String
    let permissions: [String]
    let userId: String?
}

struct Comment: Codable {
    let id: String
    let collectionId: String
    let databaseId: String
    let createdAt: String
    let updatedAt: String
    let permissions: [String]
    let userId: String?
    let comment: String?
}

// For database operations - minimal data needed for storage
struct VideoDocument: Codable {
    let id: String
    let collectionId: String
    let databaseId: String
    let createdAt: String
    let updatedAt: String
    let permissions: [String]
    let caption: String?
    let likes: [Like]?
    let comments: [Comment]?
    let videoId: String?
    let users: String? // Just store the username string
}

// For app usage - full user profile included
struct Video: Codable {
    let id: String
    let collectionId: String
    let databaseId: String
    let createdAt: String
    let updatedAt: String
    let permissions: [String]
    
    // Video specific fields
    let caption: String?
    let likes: [Like]?
    let comments: [Comment]?
    let videoId: String?
    let users: UserProfile? // Full user profile for display
    
    // Initialize from VideoDocument and UserProfile
    init(from document: VideoDocument, userProfile: UserProfile?) {
        self.id = document.id
        self.collectionId = document.collectionId
        self.databaseId = document.databaseId
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
        self.permissions = document.permissions
        self.caption = document.caption
        self.likes = document.likes
        self.comments = document.comments
        self.videoId = document.videoId
        self.users = userProfile
    }
    
    enum CodingKeys: String, CodingKey {
        case id, collectionId, databaseId, createdAt, updatedAt, permissions
        case caption, likes, comments, videoId, users
    }
    
    var timeAgo: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = dateFormatter.date(from: createdAt) else {
            return "Invalid date"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "hh:mm:ss a"
        return displayFormatter.string(from: date)
    }
    
    var likeCount: Int {
        return likes?.count ?? 0
    }
    
    var commentCount: Int {
        return comments?.count ?? 0
    }
    
    var thumbnailURL: URL? {
        guard let videoId = videoId else { return nil }
        return AppwriteManager.shared.getThumbnailURL(thumbnailId: videoId)
    }
}
