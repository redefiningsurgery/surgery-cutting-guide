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
        let directory = documentsDirectory.appendingPathComponent(createRecordingDirectoryName(), conformingTo: .directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        let depthMapPath = directory.appendingPathComponent("depth.png", conformingTo: .fileURL)
        let depthMapPng = try encodeDepthMapToPng(depthData.depthMap)
        try depthMapPng.write(to: depthMapPath)
        
        let rgbPath = directory.appendingPathComponent("rgb.png", conformingTo: .fileURL)
        let rgbPng = try encodeRgbToPng(frame.capturedImage)
        try rgbPng.write(to: rgbPath)
        
        let cameraDataPath = directory.appendingPathComponent("camera.txt", conformingTo: .fileURL)
        try saveCameraTransform(camera: frame.camera, path: cameraDataPath)
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

fileprivate func saveCameraTransform(camera: ARCamera, path: URL) throws {
    var contents = "# camera data - https://developer.apple.com/documentation/arkit/arcamera \n\n"
    
    contents += "transform = \(camera.transform.toArray())" + "\n\n"

    // https://developer.apple.com/documentation/arkit/arcamera/2875730-intrinsics
    let intrinsics = camera.intrinsics
    let fx = intrinsics.columns.0.x
    let fy = intrinsics.columns.1.y
    let ox = intrinsics.columns.2.x
    let oy = intrinsics.columns.2.y
    contents += "intrinsics = \(intrinsics.toArray())" + "\n"
    contents += "fx = \(fx)" + "\n"
    contents += "fy = \(fy)" + "\n"
    contents += "ox = \(ox)" + "\n"
    contents += "oy = \(oy)" + "\n"
    contents += "\n"

    contents += "roll = \(camera.eulerAngles.x)" + "\n" // rotation around the x-axis
    contents += "pitch = \(camera.eulerAngles.y)" + "\n" // rotation around the y-axis
    contents += "yaw = \(camera.eulerAngles.z)" + "\n" // rotation around the z-axis
    contents += "\n"

    try contents.write(to: path, atomically: true, encoding: .utf8)
}

extension FileHandle {
    func writeLine(_ text: String) throws {
        let line = "\(text)\n".data(using: .utf8)!
        try self.write(contentsOf: line)
    }
}


extension simd_float3x3 {
    func toArray() -> [Float] {
        return [
            self.columns.0.x, self.columns.1.x, self.columns.2.x, // First row
            self.columns.0.y, self.columns.1.y, self.columns.2.y, // Second row
            self.columns.0.z, self.columns.1.z, self.columns.2.z  // Third row
        ]
    }
}

extension simd_float4x4 {
    func toArray() -> [Float] {
        // i know it's weird, but w is the last column
        return [
            self.columns.0.x, self.columns.1.x, self.columns.2.x, self.columns.3.x, // First row
            self.columns.0.y, self.columns.1.y, self.columns.2.y, self.columns.3.y, // Second row
            self.columns.0.z, self.columns.1.z, self.columns.2.z, self.columns.3.z, // Third row
            self.columns.0.w, self.columns.1.w, self.columns.2.w, self.columns.3.w  // Fourth row
        ]
    }
}
