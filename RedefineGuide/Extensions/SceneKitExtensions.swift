//
//  SceneKitExtensions.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 4/10/24.
//

import Foundation
import SceneKit
import ARKit

extension SCNNode {
    
    /// Sets the euler angles based on degree inputs.
    /// - Parameters:
    ///   - node: The SCNNode to modify.
    ///   - x: The rotation around the x-axis in degrees.
    ///   - y: The rotation around the y-axis in degrees.
    ///   - z: The rotation around the z-axis in degrees.
    func rotate(x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0) {
        let radiansPerDegree = CGFloat.pi / 180
        self.eulerAngles = SCNVector3(x * radiansPerDegree, y * radiansPerDegree, z * radiansPerDegree)
    }
    
    /// Scales the node so it has the specified width in centimeters.
    func scaleToWidth(centimeters: Float) {
        let (min, max) = self.boundingBox
        let currentWidth = max.x - min.x
        let targetWidth = Float(centimeters) / 100.0
        let scaleFactor = targetWidth / currentWidth
        self.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
    }
    
    /// Gets the bounding box from the scene's view for this node
    func getBoundingBoxInScreenCoords(in sceneView: ARSCNView) -> CGRect {
        let (minCorner, maxCorner) = self.boundingBox
        
        // Create an array of vertices by combining min and max coordinates
        let vertices = [
            SCNVector3(minCorner.x, minCorner.y, minCorner.z),
            SCNVector3(maxCorner.x, minCorner.y, minCorner.z),
            SCNVector3(minCorner.x, maxCorner.y, minCorner.z),
            SCNVector3(maxCorner.x, maxCorner.y, minCorner.z),
            SCNVector3(minCorner.x, minCorner.y, maxCorner.z),
            SCNVector3(maxCorner.x, minCorner.y, maxCorner.z),
            SCNVector3(minCorner.x, maxCorner.y, maxCorner.z),
            SCNVector3(maxCorner.x, maxCorner.y, maxCorner.z)
        ].map { self.convertPosition($0, to: nil) } // Convert each vertex to world coordinates
        
        // Project all world coordinates to screen coordinates
        let screenPoints = vertices.map { sceneView.projectPoint($0) }
        
        // Find the min and max coordinates from projected points
        let minX = screenPoints.map { CGFloat($0.x) }.min() ?? 0
        let maxX = screenPoints.map { CGFloat($0.x) }.max() ?? 0
        let minY = screenPoints.map { CGFloat($0.y) }.min() ?? 0
        let maxY = screenPoints.map { CGFloat($0.y) }.max() ?? 0
        
        // Calculate width and height from min and max coordinates
        let width = maxX - minX
        let height = maxY - minY
        
        // Create and return the CGRect
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    func getAnglesInDegrees() -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        let eulerAngles = self.eulerAngles

        return (radiansToDegrees(CGFloat(eulerAngles.x)),
                radiansToDegrees(CGFloat(eulerAngles.y)),
                radiansToDegrees(CGFloat(eulerAngles.z)))
    }
}

extension SCNScene {
    
    /// Saves the current scene in the file system so it can be imported into a computer
    func export() async throws {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = dateFormatter.string(from: Date())
        let fileNameExt = "\(fileName).scn"
        let url = documentsDirectory.appendingPathComponent(fileNameExt)

        try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.write(to: url, delegate: nil, progressHandler: { (totalProgress, error, stop) in
                if totalProgress == 1.0 && error == nil {
                    continuation.resume()
                }
                if let error = error {
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    
}

func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
    let degrees = radians * 180.0 / .pi
    return degrees >= 0 ? degrees : degrees.truncatingRemainder(dividingBy: 360) + 360
}

func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
    return degrees * .pi / 180.0
}

func degreesToQuaternion(xDegrees: CGFloat, yDegrees: CGFloat, zDegrees: CGFloat) -> SCNQuaternion {
    // Convert degrees to radians
    let xRadians = degreesToRadians(xDegrees)
    let yRadians = degreesToRadians(yDegrees)
    let zRadians = degreesToRadians(zDegrees)
    
    // Create Euler angles vector
    let eulerAngles = SCNVector3(xRadians, yRadians, zRadians)
    
    // Create a node to utilize SceneKit's conversion
    let node = SCNNode()
    node.eulerAngles = eulerAngles
    return node.orientation
}

func createAxis(radius: Float, length: Float) -> SCNNode {
    // Create a cylinder that is thin and long
    let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))

    // Create a material and assign a color
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.blue
    material.transparency = 1 // todo: I don't think this worked because parent node opacity
    cylinder.materials = [material]

    // Create a node for the cylinder
    let cylinderNode = SCNNode(geometry: cylinder)
    return cylinderNode
}

func getPositionInFrontOfCamera(cameraTransform: simd_float4x4, distanceMeters: Float) -> SCNVector3 {
    // Use the camera's transform to get its current orientation and position
    let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

    // Calculate the forward vector from the camera transform
    let forwardVector = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
    let adjustedForwardPosition = forwardVector.normalized() * distanceMeters

    return cameraPosition + adjustedForwardPosition
}

func adjustedTransform(originalTransform: simd_float4x4, cameraTransform: simd_float4x4, distance: Float, xOffset: Float, yOffset: Float, zOffset: Float) -> simd_float4x4 {
    // Extract the forward vector from the camera transform (3rd row of the rotation matrix)
    let forwardVector = simd_float3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
    
    // Calculate the adjusted translation vector
    let translationAdjustment = forwardVector * distance // Move closer by 'distance'
    
    // Adjust the original translation
    var adjustedTransform = originalTransform
    adjustedTransform.columns.3.x += translationAdjustment.x + xOffset
    adjustedTransform.columns.3.y += translationAdjustment.y + yOffset
    adjustedTransform.columns.3.z += translationAdjustment.z + zOffset
    
    return adjustedTransform
}

func updateOverlayNodePositionAndOrientation(cameraTransform: simd_float4x4, overlayNode: SCNNode, distanceMeters: Float) {
    // Positioning the overlay node in front of the camera
    let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
    let forwardVector = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
    let adjustedForwardPosition = forwardVector.normalized() * distanceMeters
    let newPosition = cameraPosition + adjustedForwardPosition
    overlayNode.position = newPosition
    
    // Orient the overlay node to face the camera by calculating the direction from the node to the camera
    let cameraOrientation = simd_quatf(cameraTransform)
    overlayNode.simdOrientation = cameraOrientation
    // todo: this works but not when the phone rotates.  for that, you could detect device orientation and apply eulerAngles
    // overlayNode.eulerAngles = SCNVector3(0, Float.pi, 0)
//
//    let directionToCamera = (cameraPosition - overlayNode.position).normalized()
//    let nodeFront = SCNVector3(0, 0, -1) // Default front direction in SceneKit
//    let rotation = SCNVector3.rotationFrom(vector: nodeFront, toVector: directionToCamera)
//    overlayNode.orientation = SCNQuaternion(rotation.x, rotation.y, rotation.z, rotation.w)
}

//
//func updateOverlayNodePositionAndOrientation(cameraTransform: simd_float4x4, overlayNode: SCNNode, distanceMeters: Float) {
//    // Calculate the new position for the overlay node in front of the camera
//    let cameraPosition = simd_make_float3(cameraTransform.columns.3)
//    let forwardVector = -simd_make_float3(cameraTransform.columns.2)
//    let newPosition = cameraPosition + forwardVector * distanceMeters
//    overlayNode.simdPosition = newPosition
//
//    // Create a look-at rotation matrix to face the camera
//    let upVector = simd_make_float3(cameraTransform.columns.1)
//    let lookAtMatrix = simd_float4x4(simd_lookAt(eye: newPosition, center: cameraPosition, up: upVector))
//    overlayNode.simdOrientation = simd_quatf(lookAtMatrix)
//}


extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x * x + y * y + z * z)
        return SCNVector3(x / length, y / length, z / length)
    }
    
    static func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func -(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func *(vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
    
    static func rotationFrom(vector: SCNVector3, toVector: SCNVector3) -> SCNVector4 {
        let cosTheta = vector.dot(toVector)
        let rotationAxis = vector.cross(toVector).normalized()
        let theta = acos(min(max(cosTheta, -1.0), 1.0)) // Clamp cosTheta to avoid numerical issues
        let halfTheta = theta / 2.0
        let sinHalfTheta = sin(halfTheta)
        return SCNVector4(rotationAxis.x * sinHalfTheta, rotationAxis.y * sinHalfTheta, rotationAxis.z * sinHalfTheta, cos(halfTheta))
    }
    
    func dot(_ vector: SCNVector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }

    func cross(_ vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(y * vector.z - z * vector.y,
                          z * vector.x - x * vector.z,
                          x * vector.y - y * vector.x)
    }
}

// Helper function to create a combined rotation and translation matrix
func simd_make_float4x4(translation: SIMD3<Float>, rotation: (pitch: Float, yaw: Float, roll: Float)) -> matrix_float4x4 {
    let rotationX = makeRotationMatrix(axis: SIMD3<Float>(1, 0, 0), angle: rotation.pitch)
    let rotationY = makeRotationMatrix(axis: SIMD3<Float>(0, 1, 0), angle: rotation.yaw)
    let rotationZ = makeRotationMatrix(axis: SIMD3<Float>(0, 0, 1), angle: rotation.roll)

    let rotationMatrix = simd_mul(simd_mul(rotationX, rotationY), rotationZ)

    var translationMatrix = matrix_identity_float4x4
    translationMatrix.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)

    return simd_mul(rotationMatrix, translationMatrix)
}

func createSim4Float4x4FromRowMajor(_ array: [Float]) -> simd_float4x4? {
    guard array.count == 16 else {
        return nil
    }
    
    // Interpret the input array as row-major order, then create columns for column-major storage
    let row0 = simd_float4(array[0], array[1], array[2], array[3])
    let row1 = simd_float4(array[4], array[5], array[6], array[7])
    let row2 = simd_float4(array[8], array[9], array[10], array[11])
    let row3 = simd_float4(array[12], array[13], array[14], array[15])
    
    let matrix = simd_float4x4(rows: [row0, row1, row2, row3])
    return matrix
}


// Create a rotation matrix around an axis by an angle to avoid conflict
func makeRotationMatrix(axis: SIMD3<Float>, angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)

    let column0 = SIMD4<Float>(c + pow(axis.x, 2) * (1 - c), axis.x * axis.y * (1 - c) - axis.z * s, axis.x * axis.z * (1 - c) + axis.y * s, 0)
    let column1 = SIMD4<Float>(axis.y * axis.x * (1 - c) + axis.z * s, c + pow(axis.y, 2) * (1 - c), axis.y * axis.z * (1 - c) - axis.x * s, 0)
    let column2 = SIMD4<Float>(axis.z * axis.x * (1 - c) - axis.y * s, axis.z * axis.y * (1 - c) + axis.x * s, c + pow(axis.z, 2) * (1 - c), 0)
    let column3 = SIMD4<Float>(0, 0, 0, 1)

    return matrix_float4x4(columns: (column0, column1, column2, column3))
}

func loadMDLAsset(_ data: Data) throws -> MDLAsset {
    // Create a temporary URL to save the file
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
    let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("\(UUID().uuidString).usdz") // extension is important.  otherwise the overlay won't show
    try data.write(to: temporaryFileURL, options: [.atomic])

    print("Loading model asset of \(data.count) bytes from \(temporaryFileURL.absoluteString)")
    let asset = MDLAsset(url: temporaryFileURL)
    // delete the file cuz we don't need it
    try FileManager.default.removeItem(at: temporaryFileURL)
    return asset
}

func loadModelNode(_ data: Data) throws -> SCNNode {
    let modelAsset = try loadMDLAsset(data)
    modelAsset.loadTextures()
    let modelObject = modelAsset.object(at: 0)
    
    // this causes the UI to freeze.  but I tried to put it in a background task and that didn't help. we'll have to handle this later
    return SCNNode(mdlObject: modelObject)
}
