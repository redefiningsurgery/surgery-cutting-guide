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
    let cylinder = SCNCylinder(radius: 0.002, height: 1.0)  // Adjust radius for thinness and height for length

    // Create a material and assign a color
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.red  // Color can be changed based on the axis color requirement
    material.specular.contents = UIColor.white  // Highlights
//    material.metalness.contents = 1.0  // Metal-like properties
    cylinder.materials = [material]

    // Create a node for the cylinder
    let cylinderNode = SCNNode(geometry: cylinder)
    cylinderNode.position = SCNVector3(x: 0, y: 0, z: -0.5)  // Position the cylinder in the scene

    // Optionally, rotate the cylinder to align it as needed
    // Here, it's aligned along the z-axis
    cylinderNode.eulerAngles = SCNVector3(x: Float.pi/2, y: 0, z: 0)

    // to make light for the specular highlights
//    // Ensure there's a light in the scene to see the specular highlights
//    let lightNode = SCNNode()
//    lightNode.light = SCNLight()
//    lightNode.light!.type = .omni
//    lightNode.position = SCNVector3(x: 0, y: 1, z: 1)
//    view.scene.rootNode.addChildNode(lightNode)
    
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

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x * x + y * y + z * z)
        return SCNVector3(x / length, y / length, z / length)
    }
    
    static func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func *(vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
}
