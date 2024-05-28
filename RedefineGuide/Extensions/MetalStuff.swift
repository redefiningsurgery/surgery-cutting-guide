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
    
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache!, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
}


func createAxisMaterial() -> SCNMaterial {
    let material = SCNMaterial()
//    material.isDoubleSided = true
//    material.blendMode = .alpha
//    material.transparency = 0.5
    material.diffuse.contents = UIColor.red  // Color can be changed based on the axis color requirement
    // https://github.com/search?q=%22%23pragma+arguments%22+AND+%22shaderModifiers%22+AND+%22fragment%22+AND+%22sample%22&type=code
    
    // https://github.com/theos/sdks/blob/ca52092676249546f08657d4fc0c8beb26a80510/iPhoneOS12.4.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNShadable.h#L69
    material.shaderModifiers = [
        .fragment: """
        #pragma arguments
        texture2d<float, access::sample> depthTexture;

        #pragma body
        constexpr sampler depthSampler(coord::pixel);

        float depthValue = depthTexture.sample(depthSampler, float2(0.0, 0.0)).r; // Sample the depth texture at (0,0)
        if (depthValue < 0.05) {
        
            _output.color.a = 0;
        }
        // _output.color.a = clamp(depthValue, 0.0, 1.0);
        """,
    ]
    return material
}

func setAxisMetalStuff(_ depthData: CVPixelBuffer, _ axisMaterial: SCNMaterial) {
    let depthMap = copyAndModifyPixelBuffer(originalBuffer: depthData, value: 0.0)
//    var texturePixelFormat: MTLPixelFormat!
//    setMTLPixelFormat(&texturePixelFormat, basedOn: depthMap)
//    let depthTexture = MetalStuff.shared.createTexture(fromPixelBuffer: depthMap, pixelFormat: texturePixelFormat, planeIndex: 0)
//    let depthTexture = MetalStuff.shared.createTexture(depthMap)
    //axisMaterial.setValue(depthTexture, forKey: "depthTexture")
//    let texture = createSinglePixelTexture(device: MetalStuff.shared.device!, value: 0.0)
    //axisMaterial.setValue(texture, forKey: "depthTexture")
    axisMaterial.setValue(SCNMaterialProperty(contents: pixelBufferToImage(depthMap)), forKey: "depthTexture")

//    let sampler = MTLSamplerDescriptor()
//    sampler.minFilter = .nearest
//    sampler.magFilter = .nearest
//    
//    let samplerState = MetalStuff.shared.device!.makeSamplerState(descriptor: sampler)
//    axisMaterial.setValue(samplerState, forKey: "depthSampler")
}

func pixelBufferToImage(_ buffer: CVPixelBuffer) -> CGImage {
    let ciContext = CIContext()
    let ciImage = CIImage(cvPixelBuffer: buffer)
    if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
        return cgImage
    }
    fatalError()
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

// Assigns an appropriate MTL pixel format given the argument pixel-buffer's format.
fileprivate func setMTLPixelFormat(_ texturePixelFormat: inout MTLPixelFormat?, basedOn pixelBuffer: CVPixelBuffer!) {
    if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32 {
        texturePixelFormat = .r32Float
    } else if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_OneComponent8 {
        texturePixelFormat = .r8Uint
    } else {
        fatalError("Unsupported ARDepthData pixel-buffer format.")
    }
}

func createSinglePixelTexture(device: MTLDevice, value: Float) -> MTLTexture? {
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .r32Float,  // Single-channel 32-bit float
        width: 1,                // Width of the texture
        height: 1,               // Height of the texture
        mipmapped: false         // No mipmaps
    )
    textureDescriptor.usage = [.shaderRead, .shaderWrite]  // Usage settings

    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
        return nil
    }

    var pixelValue = value  // Value to set, could be 0.0 or 1.0
    let region = MTLRegionMake2D(0, 0, 1, 1)  // Define the region of the texture to modify

    texture.replace(region: region, mipmapLevel: 0, withBytes: &pixelValue, bytesPerRow: 4)
    return texture
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
