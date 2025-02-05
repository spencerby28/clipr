import AVFoundation

/// Converts a MOV file at the given URL to MP4 and returns the URL of the converted file.
/// The output video will be resized to 576 × 1024.
/// - Parameter inputURL: The URL pointing to the original MOV file.
/// - Returns: A URL pointing to the converted MP4 file.
/// - Throws: An error if the export fails.
func convertMovToMp4(inputURL: URL) async throws -> URL {
    let startTime = Date()
    print("🎬 Starting MOV to MP4 conversion at: \(startTime)")
    print("📊 Input file size: \(try FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] ?? 0) bytes")
    
    let asset = AVAsset(url: inputURL)
    
    // Create an export session with a high-quality preset.
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
        throw NSError(
            domain: "VideoConversion",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."]
        )
    }
    
    print("⚙️ Setting up video composition...")
    // Set up video composition for resizing
    let composition = AVMutableVideoComposition()
    composition.renderSize = CGSize(width: 576, height: 1024)
    composition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
    
    guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
        throw NSError(
            domain: "VideoConversion",
            code: -4,
            userInfo: [NSLocalizedDescriptionKey: "No video track found."]
        )
    }
    
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    
    // Calculate transform to maintain aspect ratio
    let assetSize = try await videoTrack.load(.naturalSize)
    let scale = min(576 / assetSize.width, 1024 / assetSize.height)
    let transform = CGAffineTransform(scaleX: scale, y: scale)
    
    layerInstruction.setTransform(transform, at: .zero)
    instruction.layerInstructions = [layerInstruction]
    composition.instructions = [instruction]
    
    // Create a temporary output URL for the MP4 file.
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.videoComposition = composition
    
    try await withCheckedThrowingContinuation { continuation in
        print("🔄 Starting export process...")
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                print("✅ MP4 conversion completed at: \(endTime)")
                print("⏱️ Conversion duration: \(duration) seconds")
                if let outputURL = exportSession.outputURL {
                    print("📊 Output file size: \(try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] ?? 0) bytes")
                }
                continuation.resume(returning: ())
                
            case .failed:
                let error = exportSession.error ?? NSError(
                    domain: "VideoConversion",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown export error."]
                )
                print("❌ Export failed: \(error)")
                continuation.resume(throwing: error)
                
            case .cancelled:
                let error = NSError(
                    domain: "VideoConversion",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Export cancelled."]
                )
                print("⚠️ Export cancelled")
                continuation.resume(throwing: error)
                
            default:
                break
            }
        }
    }
    
    return outputURL
} 