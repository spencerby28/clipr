//
//  Reel.swift
//  ReelsLayout
//
//  Created by Balaji Venkatesh on 13/11/23.
//

import SwiftUI

/// Reel Model & Sample Video Files
struct Reel: Identifiable {
    var id: UUID = .init()
    var videoID: String
    var authorName: String
    var isLiked: Bool = false
}

var reelsData: [Reel] = [
    /// Video from Appwrite storage
    .init(videoID: "https://appwrite.sb28.xyz/v1/storage/buckets/clips/files/67a4d8fbcf29841e83de/view?project=clipr", authorName: "Appwrite Storage"),
    /// Video from Appwrite storage
    .init(videoID: "https://appwrite.sb28.xyz/v1/storage/buckets/clips/files/67a4d8fbcf29841e83de/view?project=clipr", authorName: "Appwrite Storage"),
    /// Video from Appwrite storage  
    .init(videoID: "https://appwrite.sb28.xyz/v1/storage/buckets/clips/files/67a4d8fbcf29841e83de/view?project=clipr", authorName: "Appwrite Storage"),
    /// Video from Appwrite storage
    .init(videoID: "https://appwrite.sb28.xyz/v1/storage/buckets/clips/files/67a4d8fbcf29841e83de/view?project=clipr", authorName: "Appwrite Storage"),
    /// Video from Appwrite storage
    .init(videoID: "https://appwrite.sb28.xyz/v1/storage/buckets/clips/files/67a4d8fbcf29841e83de/view?project=clipr", authorName: "Appwrite Storage")
]
