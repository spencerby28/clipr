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
    
    enum CodingKeys: String, CodingKey {
        case id, collectionId, databaseId, createdAt, updatedAt, permissions
        case caption, likes, comments, videoId
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
}
