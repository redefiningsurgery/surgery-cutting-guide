//
//  DepthManager.swift
//  RedefineCapture
//
//  Created by Stephen Potter on 2/21/24.
//

import Foundation
import ARKit
import os.log

/// Handles communication with the device and ARKit to support preview, recording, and saving of depth maps.
/// This is used by RecorderController and does not support the recording lifecycle, like determining if something is recording
final class DepthManager: NSObject {
    private var logger = RedefineLogger("DepthManager")
    private let arSession = ARSession()
    private var arConfiguration: ARWorldTrackingConfiguration
    private let signposter: OSSignposter
    private let signpostID: OSSignpostID

    private var addToPreviewStream: ((CIImage) -> Void)?
    var showDepthInPreview: Bool = false
    
    var isPreviewPaused = false

    lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()

    override init() {
        signposter = OSSignposter(subsystem: getDomain(), category: "DepthManager")
        signpostID = signposter.makeSignpostID()
        arConfiguration = ARWorldTrackingConfiguration()
        super.init()
        arSession.delegate = self
    }
    
    func start() async throws {
        guard ARWorldTrackingConfiguration.isSupported && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            throw logger.logAndGetError("Device does not have necessary AR capabilities")
        }
        if let hiResFormat = ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution {
            arConfiguration.videoFormat = hiResFormat
        } else {
            logger.warning("Warning: ARKit 4k rgb resolution is not supported on this device")
        }
        arConfiguration.frameSemantics.insert(.sceneDepth)
        arSession.run(arConfiguration)
    }
    
    func unload() async throws {
        arSession.pause()
    }

    deinit {
        arSession.pause()
    }
    
    func startRecording(directory: URL) async throws {
    }

    func stopRecording() async throws {
    }

    func togglePreviewStream() {
        self.showDepthInPreview = !self.showDepthInPreview
    }
}

extension DepthManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // allows us to profile and view the rate that ARFrames are coming in with
        signposter.emitEvent("GotARFrame", id: signpostID)

        if showDepthInPreview {
            if let depthMap = frame.sceneDepth?.depthMap {
                let image = CIImage(cvPixelBuffer: depthMap)
                addToPreviewStream?(image)
            }
        } else {
            let image = CIImage(cvPixelBuffer: frame.capturedImage)
            addToPreviewStream?(image)
        }
//        guard let datasetEncoder = self.recordingSaver else {
//            return
//        }
//        datasetEncoder.add(frame)
    }
}
