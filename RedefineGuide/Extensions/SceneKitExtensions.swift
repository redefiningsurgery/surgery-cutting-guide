//
//  SceneKitExtensions.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 4/10/24.
//

import Foundation
import SceneKit
import ARKit
import QuartzCore

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
}

func createAxisMaterial() -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.red  // Color can be changed based on the axis color requirement
    material.specular.contents = UIColor.white  // Highlights
    // material.transparency = 0.5 // Semi-transparent
    material.fillMode = .lines // outline
    material.shaderModifiers = [
        SCNShaderModifierEntryPoint.fragment: """
        #pragma arguments
        uniform float intensity;

        #pragma transparent
        #pragma body

        vec4 originalColor = _output.color;
        float depth = gl_FragCoord.z / gl_FragCoord.w;
        float attenuation = 1.0 - depth * intensity;
        _output.color = originalColor * attenuation;
        """
    ]
    //    material.writesToDepthBuffer = true
    //    material.metalness.contents = 1.0  // Metal-like properties
    return material
}

func createAxis() -> SCNNode {
    // Create a cylinder that is thin and long
    let cylinder = SCNCylinder(radius: 0.008, height: 1.0)  // Adjust radius for thinness and height for length

    // Create a material and assign a color
    cylinder.materials = [createAxisMaterial()]

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
