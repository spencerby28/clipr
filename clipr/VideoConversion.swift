import AVFoundation

/// Converts a MOV file at the given URL to MP4 and returns the URL of the converted file.
/// - Parameter inputURL: The URL pointing to the original MOV file.
/// - Returns: A URL pointing to the converted MP4 file.
/// - Throws: An error if the export fails.
func convertMovToMp4(inputURL: URL) async throws -> URL {
    let asset = AVAsset(url: inputURL)
    
    // Create an export session with a high-quality preset.
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
        throw NSError(
            domain: "VideoConversion",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."]
        )
    }
    
    // Create a temporary output URL for the MP4 file.
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    
    try await withCheckedThrowingContinuation { continuation in
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                continuation.resume(returning: ())
                
            case .failed:
                let error = exportSession.error ?? NSError(
                    domain: "VideoConversion",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown export error."]
                )
                continuation.resume(throwing: error)
                
            case .cancelled:
                let error = NSError(
                    domain: "VideoConversion",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Export cancelled."]
                )
                continuation.resume(throwing: error)
                
            default:
                break
            }
        }
    }
    
    return outputURL
} 