import Foundation
import CoreImage
import ARKit

/// Constructs the request body to get tracking position from the server
func makeTrackingRequest(sessionId: String, frame: ARFrame) throws -> Requests_GetPositionInput {
    guard let depthData = frame.sceneDepth else {
        throw getError("ARFrame did not have sceneDepth data")
    }

    var request = Requests_GetPositionInput()
    request.sessionID = sessionId
    request.depthMap = try encodeDepthMapToPng(depthData.depthMap)
    request.rgbImage = try encodeRgbToPng(frame.capturedImage)
    // https://developer.apple.com/documentation/arkit/arcamera/2875730-intrinsics
    request.intrinsics = frame.camera.intrinsics.toArray()
    request.transform = frame.camera.transform.toArray()
    return request
}

/// Saves the request data to the phone so it can be re-sent and analyzed later.  Note that the server might also make a copy, but this is good to have.
/// It saves the raw request data, but also saves files in the format that FoundationPose's YcbineoatReader expects
func saveArFrame(_ sessionId: String, serverRequest: Requests_GetPositionInput) throws -> URL {
    do {
        // Get the documents directory path
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documentsDirectory.appendingPathComponent(sessionId, conformingTo: .directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        let requestDataPath = directory.appendingPathComponent("latest_track_request.bin", conformingTo: .fileURL)
        let requestData = try serverRequest.serializedData()
        requestData.write(to: requestDataPath)
        
        try saveToSubdirectory(directory: directory, subdirectory: "rgb", fileName: "0.png", data: serverRequest.rgbImage)
        try saveToSubdirectory(directory: directory, subdirectory: "depth", fileName: "0.png", data: serverRequest.depthMap)

        let intrinsics = serverRequest.intrinsics
        let intrinsicsStr = 
        "\(intrinsics[0]) \(intrinsics[1]) \(intrinsics[2])\n" +
        "\(intrinsics[3]) \(intrinsics[4]) \(intrinsics[5])\n" +
        "\(intrinsics[6]) \(intrinsics[7]) \(intrinsics[8])" +
        let intrinsicsPath = directory.appendingPathComponent("cam_K.txt", conformingTo: .fileURL)
        try intrinsicsStr.write(to: intrinsicsPath, atomically: true, encoding: .utf8)
        
        let transform = serverRequest.transform
        let transformStr =
        "\(transform[0]) \(transform[1]) \(transform[2]) \(transform[3])\n"
        
        let cameraDataPath = directory.appendingPathComponent("camera.txt", conformingTo: .fileURL)
        try saveCameraTransform(camera: frame.camera, path: cameraDataPath)
        return documentsDirectory
    }
}

func createSubdirectory(directory: URL, subdirectory: String) throws -> URL {
    let subdir = directory.appendingPathComponent(subdirectory, conformingTo: .directory)
    try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true, attributes: nil)
    return subdir
}

func saveToSubdirectory(directory: URL, subdirectory: String, fileName: String, data: Data) throws {
    let subdir = createSubdirectory(directory: directory, subdirectory: subdirectory)
    let filePath = subdir.appendingPathComponent(fileName, conformingTo: .fileURL)
    try data.write(to: filePath)
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
    let height = CVPixelBufferGetHeight(depthMap) // 196
    let width = CVPixelBufferGetWidth(depthMap) // 256

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

/// Writes camera odometry to a file.  Note this is done in Python syntax for copy/paste
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
