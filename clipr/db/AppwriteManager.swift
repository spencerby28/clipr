import Foundation
import SwiftUI
import Appwrite
import JSONCodable

class AppwriteManager: ObservableObject {
    static let shared = AppwriteManager()
    static let bucketId = "clips"
    
    public let appwrite: Appwrite
    
    @Published var isAuthenticated = false
    
    private init() {
        self.appwrite = Appwrite()
        
        Task {
            self.isAuthenticated = await appwrite.checkSession()
        }
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
