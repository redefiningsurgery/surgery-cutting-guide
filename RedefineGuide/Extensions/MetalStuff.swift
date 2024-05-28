//
//  MetalStuff.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 5/24/24.
//

import Foundation
import CoreMedia
import MetalKit
import MetalPerformanceShaders
import SceneKit
import ARKit

class MetalStuff {
    static let shared = MetalStuff()
    private var logger = RedefineLogger("MetalStuff")

    lazy var device: MTLDevice? = {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            logger.error("No metal device")
            return nil
        }
        return metalDevice
    }()
    
    lazy var textureCache: CVMetalTextureCache? = {
        guard let metalDevice = self.device else {
            logger.error("No metal device")
            return nil
        }
        
        var metalTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
            logger.error("Could not create texture cache")
            return nil
        } else {
            return metalTextureCache!
        }
    }()

    func createTexture(_ pixelBuffer:CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else {
            return nil
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTextureOut:CVMetalTexture?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
        if result != kCVReturnSuccess {
            logger.error("Pixel buffer conversion failed")
            return nil
        }
        
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            logger.error("Failed to create preview texture")
            CVMetalTextureCacheFlush(textureCache, 0)
            return nil
        }
        
        return texture
    }
    
}


func createAxisMaterial() -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.red  // Color can be changed based on the axis color requirement
    material.shaderModifiers = [
        SCNShaderModifierEntryPoint.fragment: """
        #pragma arguments
        texture2d<float, access::sample> depthTexture;
        sampler depthSampler;  // You need a sampler to read from the texture

        #pragma body
        float depthValue = depthTexture.sample(depthSampler, float2(0.0, 0.0)).r; // Sample the depth texture at (0,0)
        _output.color.a = depthValue;
        // _output.color.a = clamp(depthValue, 0.0, 1.0);
        //        if (depthValue < 0.1) {
        //            _output.color.a = 0.0;  // Make pixel fully transparent if depth is less than 0.1
        //        } else {
        //            _output.color.a = 1;  // Otherwise, use a semi-transparent value
        //        }
        """,

    ]
    return material
}

func setAxisMetalStuff(_ depthData: CVPixelBuffer, _ axisMaterial: SCNMaterial) {
    let depthMap = copyAndModifyPixelBuffer(originalBuffer: depthData, value: 0.0)
    let depthTexture = MetalStuff.shared.createTexture(depthMap)
    axisMaterial.setValue(depthTexture, forKey: "depthTexture")
    let sampler = MTLSamplerDescriptor()
    sampler.minFilter = .nearest
    sampler.magFilter = .nearest
    
    let samplerState = MetalStuff.shared.device!.makeSamplerState(descriptor: sampler)
    axisMaterial.setValue(samplerState, forKey: "depthSampler")
}

func copyAndModifyPixelBuffer(originalBuffer: CVPixelBuffer, value: Float) -> CVPixelBuffer {
    let width = CVPixelBufferGetWidth(originalBuffer)
    let height = CVPixelBufferGetHeight(originalBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(originalBuffer)

    var newPixelBuffer: CVPixelBuffer?
    let attributes = [
        kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
    ] as CFDictionary
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attributes, &newPixelBuffer)

    guard let buffer = newPixelBuffer else { fatalError("Could not create new pixel buffer") }

    CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferLockBaseAddress(originalBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let bufferAddress = CVPixelBufferGetBaseAddress(buffer)
    let originalAddress = CVPixelBufferGetBaseAddress(originalBuffer)

    memcpy(bufferAddress, originalAddress, CVPixelBufferGetDataSize(originalBuffer))

    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    let floatBuffer = bufferAddress!.bindMemory(to: Float.self, capacity: width * height)

    for row in 0..<height {
        for col in 0..<width {
            floatBuffer[row * (rowBytes / MemoryLayout<Float>.size) + col] = value
        }
    }

    CVPixelBufferUnlockBaseAddress(originalBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

    return buffer
}


// depth2d<float, access::sample> sceneDepthTexture [[ texture(3) ]],

//
//fragment float4 capturedImageFragmentShader(ImageColorInOut in [[stage_in]],
//                                            texture2d<float, access::sample> textureY [[ texture(1) ]],
//                                            texture2d<float, access::sample> textureCbCr [[ texture(2) ]]) {
//    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
//    const float4x4 ycbcrToRGBTransform = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
//                                                  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
//                                                  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
//                                                  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));
//    float4 ycbcr = float4(textureY.sample(colorSampler, in.texCoord).r, textureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
//    return ycbcrToRGBTransform * ycbcr;
//}

//        SCNShaderModifierEntryPoint.surface: """
//            float dotProduct = dot(_surface.view, _surface.normal);
//            // I'm clamping it so all negative values are just 0
//            dotProduct = dotProduct < 0.0 ? 0.0 : dotProduct;
//            _surface.diffuse.rgb = vec3(1.0, 1.0, 0.0);
//            float a = dotProduct;
//            _surface.diffuse = vec4(_surface.diffuse.rgb * a, a);
//            """
//"""
//#pragma arguments
//texture2d<float, access::sample> capturedImageTextureY;
//texture2d<float, access::sample> capturedImageTextureCbCr;
//
//#pragma body
//constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
//
//const float4x4 ycbcrToRGBTransform = float4x4(
//  float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
//  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
//  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
//  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
//);
//
//// Flip Y
//float2 texCoord = float2( _surface.diffuseTexcoord.x, 1.0f - _surface.diffuseTexcoord.y );
//
//// Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
//float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, texCoord).r,
//                      capturedImageTextureCbCr.sample(colorSampler, texCoord).rg, 1.0);
//
//// Convert to RGB
//_surface.diffuse = ycbcrToRGBTransform * ycbcr;
//"""
