import Foundation
import CoreImage
import ARKit

/// Stores the RGB and depth map to png files in a new directory, which is named by using a timestamp
func saveArFrame(_ frame: ARFrame) throws -> URL {
    do {
        guard let depthData = frame.sceneDepth else {
            throw getError("ARFrame did not have sceneDepth data")
        }
        // Get the documents directory path
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documentsDirectory.appendingPathComponent(createRecordingDirectoryName(), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        let depthMapPath = directory.appendingPathComponent("depth.png", isDirectory: false)
        let depthMapPng = try encodeDepthMapToPng(depthData.depthMap)
        try depthMapPng.write(to: depthMapPath)
        
        let rgbPath = directory.appendingPathComponent("rgb.png", isDirectory: false)
        let rgbPng = try encodeRgbToPng(frame.capturedImage)
        try rgbPng.write(to: rgbPath)
        
        return documentsDirectory
    }
}

fileprivate func createRecordingDirectoryName() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return dateFormatter.string(from: Date())
}

/// Takes the camera image and converts it to a PNG
fileprivate func encodeRgbToPng(_ rgbImage: CVPixelBuffer) throws -> Data {
    let ciContext = CIContext()
    let ciImage = CIImage(cvPixelBuffer: rgbImage)
    
    // Convert to CGImage for PNG creation
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
        throw getError("Unable to create CGImage")
    }

    // Create UIImage from CGImage
    let image = UIImage(cgImage: cgImage)

    // Convert UIImage to PNG data
    guard let pngData = image.pngData() else {
        throw getError("Unable to create PNG data")
    }
    
    return pngData
}

/// Takes the depth map and encodes it to a PNG.  This is a
fileprivate func encodeDepthMapToPng(_ depthMap: CVPixelBuffer) throws -> Data {
    guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else {
        throw getError("Depth map was in the wrong pixel format.")
    }
    let height = CVPixelBufferGetHeight(depthMap)
    let width = CVPixelBufferGetWidth(depthMap)
    CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags.readOnly)
    guard let inBase = CVPixelBufferGetBaseAddress(depthMap) else {
        throw getError("Could not get pixel buffer address")
    }
    
    let inPixelData = inBase.assumingMemoryBound(to: Float32.self)
    // PngEncoder handles grayscale depth information so color space is not necessary
    let out = PngEncoder.init(depth: inPixelData, width: Int32(width), height: Int32(height))!
    CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
    return out.fileContents()
}
