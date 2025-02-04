//
//  appwrite.swift
//  clipr
//
//  Created by Spencer Byrne on 2/3/25.
//

import Foundation
import Appwrite
import JSONCodable

class Appwrite {
    var client: Client
    var account: Account
    var databases: Databases
    var storage: Storage
    
    public init() {
        self.client = Client()
            .setEndpoint("https://appwrite.sb28.xyz/v1")
            .setProject("clipr")
            .setSelfSigned()
        
        self.account = Account(client)
        self.databases = Databases(client)
        self.storage = Storage(client)
    }
    
    public func checkSession() async -> Bool {
        do {
            // Try to get the current session
            let sessions = try await account.listSessions()
            return !sessions.sessions.isEmpty
        } catch {
            print("Session check error: \(error)")
            return false
        }
    }
    
    public func onRegister(
        _ email: String,
        _ password: String
    ) async throws -> User<[String: AnyCodable]> {
        do {
            let user = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password
            )
            _ = try await onLogin(email, password)
            return user
        } catch {
            print("Registration error: \(error)")
            throw error
        }
    }
    
    public func onLogin(
        _ email: String,
        _ password: String
    ) async throws -> Session {
        do {
            let session = try await account.createEmailPasswordSession(
                email: email,
                password: password
            )
            return session
        } catch {
            print("Login error: \(error)")
            throw error
        }
    }
    
    public func onLogout() async throws {
        do {
            _ = try await account.deleteSessions()
        } catch {
            print("Logout error: \(error)")
            throw error
        }
    }
    
    // Add video storage methods
    public func uploadVideo(fileData: Data, fileName: String) async throws -> File {
        do {
            let inputFile = InputFile.fromData(fileData, filename: fileName, mimeType: "video/mp4")
            
            let file = try await storage.createFile(
                bucketId: "clips",
                fileId: ID.unique(),
                file: inputFile
            )
            return file
        } catch {
            print("Video upload error: \(error)")
            throw error
        }
    }
    
public func getFileViewURL(bucketId: String, fileId: String) -> URL? {
        let endpoint = "https://appwrite.sb28.xyz/v1"
        let urlString = "\(endpoint)/storage/buckets/\(bucketId)/files/\(fileId)/view"
        return URL(string: urlString)
}
}

