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
}

func createAxis() -> SCNNode {
    // Create a cylinder that is thin and long
    let cylinder = SCNCylinder(radius: 0.002, height: 0.1)

    // Create a material and assign a color
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.blue
    material.transparency = 1 // parent may be translucent so make this solid
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
