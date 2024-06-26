import Foundation
import CoreImage
import ARKit

/// Constructs the request body to get tracking position from the server
func makeTrackingRequest(sessionId: String, frame: ARFrame) throws -> Requests_GetPositionInput {
    guard let depthData = frame.smoothedSceneDepth else {
        throw getError("ARFrame did not have smoothedSceneDepth data")
    }

    var request = Requests_GetPositionInput()
    request.sessionID = sessionId
    request.depthMap = try encodeDepthMapToPng(depthData.depthMap)
    request.rgbImage = try encodeRgbToPng(frame.capturedImage)
    // https://developer.apple.com/documentation/arkit/arcamera/2875730-intrinsics
    request.intrinsics = frame.camera.intrinsics.toArrayRowMajor()
    request.transform = frame.camera.transform.toArrayRowMajor()
    // use the fast version when it's being continuously updated.  but if updates are only occasional, use the slow approach because if you move the camera significantly without updating, it'll expect incremental approaches and won't consider the correct pose
    request.optimizeForSpeed = Settings.shared.continuouslyTrack
    return request
}

/// Saves the request data to the phone so it can be re-sent and analyzed later.  Note that the server might also make a copy, but this is good to have.
/// It saves the raw request data, but also saves files in the format that FoundationPose's YcbineoatReader expects
func saveTrackingRequest(_ serverRequest: Requests_GetPositionInput) throws {
    // Get the documents directory path
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let directory = documentsDirectory.appendingPathComponent(serverRequest.sessionID, conformingTo: .directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    
    let requestDataPath = directory.appendingPathComponent("latest_track_request.bin", conformingTo: .fileURL)
    let requestData = try serverRequest.serializedData()
    try requestData.write(to: requestDataPath)
    
    try saveToSubdirectory(directory: directory, subdirectory: "rgb", fileName: "0.png", data: serverRequest.rgbImage)
    try saveToSubdirectory(directory: directory, subdirectory: "depth", fileName: "0.png", data: serverRequest.depthMap)

    // save intrinsics in the format that FoundationPose likes
    let intrinsics = serverRequest.intrinsics
    let intrinsicsStr =
        "\(intrinsics[0]) \(intrinsics[1]) \(intrinsics[2])\n" +
        "\(intrinsics[3]) \(intrinsics[4]) \(intrinsics[5])\n" +
        "\(intrinsics[6]) \(intrinsics[7]) \(intrinsics[8])"
    let intrinsicsPath = directory.appendingPathComponent("cam_K.txt", conformingTo: .fileURL)
    try intrinsicsStr.write(to: intrinsicsPath, atomically: true, encoding: .utf8)
    
    let transform = serverRequest.transform
    let transformStr =
        "\(transform[0]) \(transform[1]) \(transform[2]) \(transform[3])\n" +
        "\(transform[4]) \(transform[5]) \(transform[6]) \(transform[7])\n" +
        "\(transform[8]) \(transform[9]) \(transform[10]) \(transform[11])\n" +
        "\(transform[12]) \(transform[13]) \(transform[14]) \(transform[15])"
    let transformDir = try createSubdirectory(directory: directory, subdirectory: "ob_in_cam")
    let transformPath = transformDir.appendingPathComponent("0.txt", conformingTo: .fileURL)
    try transformStr.write(to: transformPath, atomically: true, encoding: .utf8)
}

func createSubdirectory(directory: URL, subdirectory: String) throws -> URL {
    let subdir = directory.appendingPathComponent(subdirectory, conformingTo: .directory)
    try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true, attributes: nil)
    return subdir
}

func saveToSubdirectory(directory: URL, subdirectory: String, fileName: String, data: Data) throws {
    let subdir = try createSubdirectory(directory: directory, subdirectory: subdirectory)
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

extension FileHandle {
    func writeLine(_ text: String) throws {
        let line = "\(text)\n".data(using: .utf8)!
        try self.write(contentsOf: line)
    }
}


extension simd_float3x3 {
    func toArrayRowMajor() -> [Float] {
        return [
            self.columns.0.x, self.columns.1.x, self.columns.2.x,
            self.columns.0.y, self.columns.1.y, self.columns.2.y,
            self.columns.0.z, self.columns.1.z, self.columns.2.z,
        ]
    }
}

extension simd_float4x4 {
    func toArrayRowMajor() -> [Float] {
        return [
            self.columns.0.x, self.columns.1.x, self.columns.2.x, self.columns.3.x,
            self.columns.0.y, self.columns.1.y, self.columns.2.y, self.columns.3.y,
            self.columns.0.z, self.columns.1.z, self.columns.2.z, self.columns.3.z,
            self.columns.0.w, self.columns.1.w, self.columns.2.w, self.columns.3.w,
        ]
    }
}
