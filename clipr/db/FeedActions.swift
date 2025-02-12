import Foundation
import Appwrite
import JSONCodable

class FeedActions {
    static let shared = FeedActions()
    private let appwrite = AppwriteManager.shared
    
    private init() {}
    
    /// Adds a like to a clip document
    func addLikeToClip(clipId: String) async throws -> Document<[String: AnyCodable]> {
        do {
            // First get the current document
            let clip = try await appwrite.appwrite.databases.getDocument(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.videosCollectionId,
                documentId: clipId
            )
            
            // Get current likes array or initialize empty if none
            var currentLikes = (clip.data["likes"]?.value as? [[String: Any]]) ?? []
            
            // Get current user
            guard let currentUser = appwrite.currentUser,
                  let userId = currentUser.userId else {
                throw NSError(domain: "FeedActionsError", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No current user or userId found"])
            }
            
            // Create new like object
            let newLike = Like(userId: userId)
            
            // Check if user has already liked
            let hasLiked = currentLikes.contains { like in
                guard let likeUserId = like["userId"] as? String else { return false }
                return likeUserId == userId
            }
            
            // Add to likes array if not already liked
            if !hasLiked {
                let likeDict: [String: Any] = [
                    "userId": userId
                ]
                currentLikes.append(likeDict)
                
                // Update the document
                let result = try await appwrite.appwrite.databases.updateDocument(
                    databaseId: AppwriteManager.databaseId,
                    collectionId: AppwriteManager.videosCollectionId,
                    documentId: clipId,
                    data: [
                        "likes": currentLikes
                    ]
                )
                return result
            }
            
            return clip
        } catch {
            print("Error adding like: \(error)")
            throw error
        }
    }
    
    /// Adds a comment to a clip document
    func addCommentToClip(clipId: String, commentText: String) async throws -> Document<[String: AnyCodable]> {
        do {
            // First get the current document
            let clip = try await appwrite.appwrite.databases.getDocument(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.videosCollectionId,
                documentId: clipId
            )
            
            // Get current comments array or initialize empty if none
            var currentComments = (clip.data["comments"]?.value as? [[String: Any]]) ?? []
            
            // Get current user
            guard let currentUser = appwrite.currentUser,
                  let userId = currentUser.userId else {
                throw NSError(domain: "FeedActionsError", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No current user or userId found"])
            }
            
            // Create new comment object
            let newComment = Comment(
                userId: userId,
                comment: commentText
            )
            
            // Convert comment to dictionary
            let commentDict: [String: Any] = [
                "userId": userId,
                "comment": commentText
            ]
            
            // Add to comments array
            currentComments.append(commentDict)
            
            // Update the document
            let result = try await appwrite.appwrite.databases.updateDocument(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.videosCollectionId,
                documentId: clipId,
                data: [
                    "comments": currentComments
                ]
            )
            return result
        } catch {
            print("Error adding comment: \(error)")
            throw error
        }
    }
}
