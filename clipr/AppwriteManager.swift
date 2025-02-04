import Foundation
import SwiftUI

class AppwriteManager: ObservableObject {
    static let shared = AppwriteManager()
    
    private let appwrite: Appwrite
    
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
    
    // MARK: - Authentication Methods
    
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
} 