//
//  UserSchema.swift
//  clipr
//
//  Created by Spencer Byrne on 2/5/25.
//

import Foundation

struct UserProfile: Codable {
    let id: String
    let collectionId: String
    let databaseId: String
    let createdAt: String
    let updatedAt: String
    let permissions: [String]
    
    // User specific fields
    let userId: String?
    let username: String?
    let name: String?
    let phone: String?
    let avatarId: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id, collectionId, databaseId, createdAt, updatedAt, permissions
        case userId, username, name, phone, avatarId, email
    }
}
