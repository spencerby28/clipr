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
    static let databaseId = "users"
    
    public let appwrite: Appwrite
    private var usernameCheckCancellable: AnyCancellable?
    @Published var isAuthenticated = false
    @Published var isUsernameAvailable: Bool?
    @Published var isCheckingUsername = false
    @Published var currentUser: UserProfile?
    
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
            "avatarId": avatarId,
            "createdAt": Date().ISO8601Format()
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
    func uploadVideo(fileURL: URL) async throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        
        let file = try await appwrite.uploadVideo(fileData: fileData, fileName: fileName)
        return file.id
    }
    
    /// Returns a public URL for the uploaded video.
    func getVideoURL(fileId: String, bucketId: String) -> URL? {
        return appwrite.getFileViewURL(bucketId: bucketId, fileId: fileId)
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
