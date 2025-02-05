import CoreImage

extension CIImage {
    // Create a shared context with appropriate options
    private static let sharedContext = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
        .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])
    
    var cgImage: CGImage? {
        // Use the shared context instead of creating a new one each time
        guard let cgImage = CIImage.sharedContext.createCGImage(self, from: self.extent) else {
            return nil
        }
        
        return cgImage
    }
} 