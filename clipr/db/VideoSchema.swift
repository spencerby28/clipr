//
//  VideoSchema.swift
//  clipr
//
//  Created by Spencer Byrne on 2/5/25.
//

import Foundation

struct Video: Codable {
    let id: String
    let collectionId: String
    let databaseId: String
    let createdAt: String
    let updatedAt: String
    let permissions: [String]
    
    // Video specific fields
    let userId: String       // Creator's user ID
    let caption: String?     // Optional caption 
    let likeCount: Int      // Number of likes
    let commentCount: Int    // Number of comments
    let viewCount: Int      // Number of views
    
    enum CodingKeys: String, CodingKey {
        case id, collectionId, databaseId, createdAt, updatedAt, permissions
        case userId, caption, likeCount, commentCount, viewCount
    }
}
