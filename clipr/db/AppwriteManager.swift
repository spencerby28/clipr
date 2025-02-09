import Foundation
import SwiftUI
import Appwrite
import JSONCodable
import Combine

class AppwriteManager: ObservableObject {
    static let shared = AppwriteManager()
    static let bucketId = "clips"
    static let avatarsBucketId = "avatars"
    static let usersCollectionId = "users"
    static let videosCollectionId = "clips"
    static let databaseId = "clips"
    
    public let appwrite: Appwrite
    private var usernameCheckCancellable: AnyCancellable?
    @Published var isAuthenticated = false
    @Published var isUsernameAvailable: Bool?
    @Published var isCheckingUsername = false
    @Published var currentUser: UserProfile?
    
    
    private init() {
        self.appwrite = Appwrite()
        
        Task {
            self.isAuthenticated = await appwrite.checkSession()
            if isAuthenticated {
                try? await loadCurrentUser()
            }
        }
    }
    
    // MARK: - User Management
    
    /// Checks if a username is available with debouncing
    func checkUsername(_ username: String) {
        guard !username.isEmpty else {
            self.isUsernameAvailable = nil
            return
        }
        
        self.isCheckingUsername = true
        
        // Cancel any existing check
        usernameCheckCancellable?.cancel()
        
        // Create a new debounced check
        usernameCheckCancellable = Just(username)
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] username in
                guard let self = self else { return }
                
                // Create a local copy of self for the async task
                let manager = self
                
                Task {
                    do {
                        let exists = try await manager.doesUsernameExist(username)
                        await MainActor.run {
                            self.isUsernameAvailable = !exists
                            self.isCheckingUsername = false
                        }
                    } catch {
                        print("Error checking username: \(error)")
                        await MainActor.run {
                            self.isUsernameAvailable = nil
                            self.isCheckingUsername = false
                        }
                    }
                }
            }
    }
    
    /// Checks if a username already exists in the database
    private func doesUsernameExist(_ username: String) async throws -> Bool {
        do {
            let documents = try await appwrite.databases.listDocuments(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.usersCollectionId,
                queries: [
                    Query.equal("username", value: username)
                ]
            )
            return !documents.documents.isEmpty
        } catch {
            print("Error checking username existence: \(error)")
            throw error
        }
    }
    
    /// Creates a new user profile
    func createUserProfile(name: String, username: String, email: String?, phoneNumber: String, profileImage: UIImage) async throws -> String {
        // 1. Get current account
        let account = try await getAccount()
        
        // 2. Upload avatar
        let avatarId = try await uploadAvatar(profileImage)
        
        // 3. Create user document
        let userData: [String: Any] = [
            "userId": account.id,
            "username": username,
            "name": name,
            "email": email ?? "",
            "phone": phoneNumber,
            "avatarId": avatarId
        ]
        
        // Create the document with username as ID for easy lookup
        let document = try await appwrite.databases.createDocument(
            databaseId: AppwriteManager.databaseId,
            collectionId: AppwriteManager.usersCollectionId,
            documentId: username,
            data: userData
        )
        
        // 4. Update account preferences with avatarId
        try await updateAccountPreferences(avatarId: avatarId)
        
        // 5. Load the current user
        await MainActor.run {
            Task {
                try? await loadCurrentUser()
            }
        }
        
        return document.id
    }
    
    /// Uploads a profile image to the avatars bucket
    private func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AppwriteError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        
        let file = try await appwrite.storage.createFile(
            bucketId: AppwriteManager.avatarsBucketId,
            fileId: ID.unique(),
            file: InputFile.fromData(imageData, filename: fileName, mimeType: "image/jpeg")
        )
        
        return file.id
    }
    
    /// Updates account preferences with avatar ID
    private func updateAccountPreferences(avatarId: String) async throws {
        let prefs = try await appwrite.account.getPrefs()
        var prefsDict: [String: Any] = [:]
        
        // Convert existing preferences
        for (key, value) in prefs.data {
            if let stringValue = value.value as? String {
                prefsDict[key] = stringValue
            }
        }
        
        // Add or update avatarId
        prefsDict["avatarId"] = avatarId
        
        _ = try await appwrite.account.updatePrefs(
            prefs: prefsDict
        )
    }
    
    // MARK: - User Profile Methods
    
    /// Loads the current user's profile
    @MainActor
    func loadCurrentUser() async throws {
        let account = try await getAccount()
        
        let documents = try await appwrite.databases.listDocuments(
            databaseId: AppwriteManager.databaseId,
            collectionId: AppwriteManager.usersCollectionId,
            queries: [
                Query.equal("userId", value: account.id)
            ]
        )
        
        guard let document = documents.documents.first else {
            throw NSError(domain: "AppwriteError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        
        // Create a dictionary with all the document metadata and data
        var documentDict: [String: Any] = [
            "id": document.id,
            "collectionId": document.collectionId,
            "databaseId": document.databaseId,
            "createdAt": document.createdAt,
            "updatedAt": document.updatedAt,
            "permissions": document.permissions
        ]
        
        // Add the user-specific fields from document.data
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
        let profile = try JSONDecoder().decode(UserProfile.self, from: jsonData)
        self.currentUser = profile
    }
    /// Gets the URL for a user's avatar
    func getAvatarURL(avatarId: String) -> URL? {
        return appwrite.getFileViewURL(
            bucketId: AppwriteManager.avatarsBucketId,
            fileId: avatarId
        )
    }
    
    // MARK: - Video Methods
        
    /// Uploads a video using a file URL.
    func uploadVideo(fileURL: URL, caption: String? = nil) async throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        
        // 1. Upload the video file first
        let file = try await appwrite.uploadVideo(fileData: fileData, fileName: fileName)
        
        print(currentUser)
        
        // 2. Create the video document in the database
        let videoData: [String: Any] = [
            "videoId": file.id,
            "caption": caption ?? "",
            "likes": [],
            "comments": [],
            "users": currentUser?.username
        ]
        
        // Create the document
        let document = try await appwrite.databases.createDocument(
            databaseId: AppwriteManager.databaseId,
            collectionId: AppwriteManager.videosCollectionId,
            documentId: ID.unique(),
            data: videoData
        )
        
        return document.id
    }
    
    /// Returns a public URL for the uploaded video.
    func getVideoURL(fileId: String, bucketId: String) -> URL? {
        return appwrite.getFileViewURL(bucketId: bucketId, fileId: fileId)
    }
    func uploadThumbnail(thumbnailData: Data, videoId: String) async throws -> String {
    let fileName = "\(videoId).jpg"
    let file = try await appwrite.storage.createFile(
         bucketId: "thumbnails",
         fileId: videoId,  // use the same id as the video clip
         file: InputFile.fromData(thumbnailData, filename: fileName, mimeType: "image/jpeg")
    )
    return file.id
}
    
    /// Lists all videos in the clips bucket
    func listVideos() async throws -> [AppwriteModels.File] {
        do {
            let files = try await appwrite.storage.listFiles(
                bucketId: AppwriteManager.bucketId
            )
            return files.files
        } catch {
            print("Error listing videos: \(error)")
            throw error
        }
    }
    
    /// Gets the URL for a video's thumbnail
    func getThumbnailURL(thumbnailId: String) -> URL? {
        return appwrite.getFileViewURL(bucketId: "thumbnails", fileId: thumbnailId)
    }
    
    /// Lists all videos with their metadata, sorted by creation date (newest first)
    func listVideosWithMetadata(limit: Int = 25, offset: Int = 0) async throws -> [Video] {
        do {
            print("DEBUG: listVideosWithMetadata called with limit = \(limit), offset = \(offset).")
            let documents = try await appwrite.databases.listDocuments(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.videosCollectionId,
                queries: [
                    Query.orderDesc("$createdAt"),
                    Query.limit(limit),
                    Query.offset(offset)
                ]
            )
            
            print("DEBUG: Got \(documents.documents.count) document(s) from Appwrite.")
            
            // Process documents in parallel using async/await
            return try await withThrowingTaskGroup(of: Video?.self) { group in
                var videos: [Video] = []
                
                for document in documents.documents {
                    group.addTask {
                        print("DEBUG: Processing document with ID = \(document.id).")
                        
                        // Create a dictionary with all the document metadata and data
                        var documentDict: [String: Any] = [
                            "id": document.id,
                            "collectionId": document.collectionId,
                            "databaseId": document.databaseId,
                            "createdAt": document.createdAt,
                            "updatedAt": document.updatedAt,
                            "permissions": document.permissions
                        ]
                        
                        // Add video-specific fields
                        if let videoId = document.data["videoId"]?.value as? String {
                            documentDict["videoId"] = videoId
                        }
                        
                        // Add remaining fields
                        if let caption = document.data["caption"]?.value as? String {
                            documentDict["caption"] = caption
                        }
                        if let likes = document.data["likes"]?.value as? [[String: Any]] {
                            documentDict["likes"] = likes
                        }
                        if let comments = document.data["comments"]?.value as? [[String: Any]] {
                            documentDict["comments"] = comments
                        }
                        
                        // Handle nested user object
                        if let userData = document.data["users"]?.value as? [String: Any] {
                            print("DEBUG: Found user data in document: \(userData)")
                            var userDict: [String: Any] = [:]
                            
                            // Map the user fields
                            if let id = userData["$id"] as? String { userDict["id"] = id }
                            if let collectionId = userData["$collectionId"] as? String { userDict["collectionId"] = collectionId }
                            if let databaseId = userData["$databaseId"] as? String { userDict["databaseId"] = databaseId }
                            if let createdAt = userData["$createdAt"] as? String { userDict["createdAt"] = createdAt }
                            if let updatedAt = userData["$updatedAt"] as? String { userDict["updatedAt"] = updatedAt }
                            if let permissions = userData["$permissions"] as? [String] { userDict["permissions"] = permissions }
                            if let userId = userData["userId"] as? String { userDict["userId"] = userId }
                            if let username = userData["username"] as? String { userDict["username"] = username }
                            if let name = userData["name"] as? String { userDict["name"] = name }
                            if let phone = userData["phone"] as? String { userDict["phone"] = phone }
                            if let avatarId = userData["avatarId"] as? String { userDict["avatarId"] = avatarId }
                            if let email = userData["email"] as? String { userDict["email"] = email }
                            
                            documentDict["users"] = userDict
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: documentDict)
                        return try JSONDecoder().decode(Video.self, from: jsonData)
                    }
                }
                
                // Collect results
                for try await video in group {
                    if let video = video {
                        videos.append(video)
                    }
                }
                
                // Sort by creation date since parallel processing may have changed order
                return videos.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            print("ERROR: Error listing videos with metadata: \(error)")
            throw error
        }
    }
    
    /// Fetches video metadata from the database using the storage file ID
    func fetchVideoMetadata(videoId: String) async throws -> Video? {
        do {
            let documents = try await appwrite.databases.listDocuments(
                databaseId: AppwriteManager.databaseId,
                collectionId: AppwriteManager.videosCollectionId,
                queries: [
                    Query.equal("videoId", value: videoId),
                    Query.orderDesc("$createdAt")
                ]
            )
            
            guard let document = documents.documents.first else {
                return nil
            }
            
            // Create a dictionary with all the document metadata and data
            var documentDict: [String: Any] = [
                "id": document.id,
                "collectionId": document.collectionId,
                "databaseId": document.databaseId,
                "createdAt": document.createdAt,
                "updatedAt": document.updatedAt,
                "permissions": document.permissions
            ]
            
            // Add video-specific fields
            if let videoId = document.data["videoId"]?.value as? String {
                documentDict["videoId"] = videoId
            }
            if let caption = document.data["caption"]?.value as? String {
                documentDict["caption"] = caption
            }
            if let likes = document.data["likes"]?.value as? [[String: Any]] {
                documentDict["likes"] = likes
            }
            if let comments = document.data["comments"]?.value as? [[String: Any]] {
                documentDict["comments"] = comments
            }
            if let username = document.data["users"]?.value as? String {
                documentDict["users"] = username
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: documentDict)
            return try JSONDecoder().decode(Video.self, from: jsonData)
        } catch {
            print("Error fetching video metadata: \(error)")
            throw error
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Gets the current user's account details
    func getAccount() async throws -> User<[String: AnyCodable]> {
        print("🔍 Checking authentication status...")
        guard isAuthenticated else {
            print("❌ Not authenticated")
            throw NSError(domain: "AppwriteError", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "User is not authenticated"])
        }
        
        print("✅ Authentication check passed")
        
        do {
            // Double check session
            let sessions = try await appwrite.account.listSessions()
            guard !sessions.sessions.isEmpty else {
                print("❌ No active sessions found")
                await MainActor.run {
                    self.isAuthenticated = false
                }
                throw NSError(domain: "AppwriteError", code: -1, 
                    userInfo: [NSLocalizedDescriptionKey: "No active session"])
            }
            
            print("📡 Fetching account details...")
            let user = try await appwrite.account.get()
            print("🔍 Raw account: \(user)")
            
            return user
        } catch let error as AppwriteError {
            print("❌ Appwrite error: \(String(describing: error.type)) - \(error.message)")
            if error.code == 401 {
                await MainActor.run {
                    self.isAuthenticated = false
                }
            }
            throw error
        } catch {
            print("❌ Unexpected error: \(error)")
            print("Error type: \(type(of: error))")
            print("Full error details: \(String(describing: error))")
            throw error
        }
    }
    /// Logs in using email and password.
    func login(email: String, password: String) async throws {
        do {
            _ = try await appwrite.onLogin(email, password)
            await MainActor.run {
                self.isAuthenticated = true
            }
        } catch {
            print("Login error: \(error)")
            throw error
        }
    }
    
    /// Logs out from the current session.
    func logout() async throws {
        do {
            try await appwrite.onLogout()
            await MainActor.run {
                self.isAuthenticated = false
            }
        } catch {
            print("Logout error: \(error)")
            throw error
        }
    }

    func onPhoneLogin(userId: String, secret: String) async throws {
        do {
            _ = try await appwrite.onPhoneLogin(userId, secret)
            await MainActor.run {
                self.isAuthenticated = true
            }
        } catch {
            print("Phone login error: \(error)")
            throw error
        }
    }
} 
