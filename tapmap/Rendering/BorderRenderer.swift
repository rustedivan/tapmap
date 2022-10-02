//
//  BorderRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-04-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
	let width: simd_float1
	var color: simd_float4
}

struct BorderContour {
	let contours: [VertexRing]
}

class BorderRenderer<RegionType> {
	typealias LoddedBorderHash = Int

	let rendererLabel: String
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let maxVisibleLineSegments: Int
	var lineSegmentsHighwaterMark: Int = 0
	var borderContours: [LoddedBorderHash : BorderContour]
	var frameSelectSemaphore = DispatchSemaphore(value: 1)
	let lineSegmentPrimitive: LineSegmentPrimitive
	let instanceUniforms: [MTLBuffer]
	var frameLineSegmentCount: [Int] = []
	
	var borderScale: Float
	var width: Float = 1.0
	var color: simd_float4 = simd_float4(0.0, 0.0, 0.0, 1.0)
	
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int, maxSegments: Int, label: String) {
		borderScale = 0.0
		
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.sampleCount = 4
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "lineVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "lineFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
				
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.rendererLabel = label
			self.device = device
			self.frameLineSegmentCount = Array(repeating: 0, count: bufferCount)
			self.maxVisibleLineSegments = maxSegments	// Determined experimentally and rounded up a lot
			self.instanceUniforms = (0..<bufferCount).map { bufferIndex in
				device.makeBuffer(length: maxSegments * MemoryLayout<LineInstanceUniforms>.stride, options: .storageModeShared)!
			}
			
			self.lineSegmentPrimitive = makeLineSegmentPrimitive(in: device, inside: -0.05, outside: 0.95)
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		borderContours = [:]
		
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
	}
	
	func setStyle(innerWidth: Float, outerWidth: Float, color: simd_float4) {
		self.width = innerWidth
		self.color = color
	}

	func prepareFrame(borderedRegions: [Int : RegionType], zoom: Float, zoomRate: Float, bufferIndex: Int) {
		let streamer = GeometryStreamer.shared
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		// Stream in any missing geometries at the wanted LOD level
		for borderHash in borderedRegions.keys {
			let loddedBorderHash = borderHashLodKey(borderHash, atLod: lodLevel)
			if borderContours[loddedBorderHash] == nil {
				borderLodMiss = true
				
				guard let tessellation = streamer.tessellation(for: borderHash, atLod: lodLevel, streamIfMissing: true) else {
					return
				}
				
				borderContours[loddedBorderHash] = BorderContour(contours: tessellation.contours)
			}
		}

		// Update the LOD level if we have all its geometries
		if !borderLodMiss && actualBorderLod != streamer.wantedLodLevel {
			actualBorderLod = streamer.wantedLodLevel
		}
		
		// Collect the vertex rings for the visible set of borders
		let frameRenderList: [BorderContour] = borderedRegions.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderContours[loddedKey]
		}
		
		// Generate all the vertices in all the outlines
		let regionContours = frameRenderList.flatMap { $0.contours }
		let borderBuffer = generateContourCollectionGeometry(contours: regionContours)
		guard borderBuffer.count < maxVisibleLineSegments else {
			fatalError("line segment buffer blew out at \(borderBuffer.count) vertices (max \(maxVisibleLineSegments))")
		}

		let borderZoom = zoom / (1.0 - zoomRate + zoomRate * Stylesheet.shared.borderZoomBias.value)	// Borders become wider at closer zoom levels
		frameSelectSemaphore.wait()
			self.borderScale = 1.0 / borderZoom
			self.frameLineSegmentCount[bufferIndex] = borderBuffer.count
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: borderBuffer, byteCount: MemoryLayout<LineInstanceUniforms>.stride * borderBuffer.count)
			if borderBuffer.count > lineSegmentsHighwaterMark {
				lineSegmentsHighwaterMark = borderBuffer.count
				print("\(rendererLabel) used a max of \(lineSegmentsHighwaterMark) line segments.")
			}
		frameSelectSemaphore.signal()
	}

	func renderBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render \(rendererLabel)'s borders")
		defer {
			encoder.popDebugGroup()
		}
		
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection,
																	 width: width * borderScale,
																	 color: color)
			let instances = instanceUniforms[bufferIndex]
			let count = frameLineSegmentCount[bufferIndex]
		frameSelectSemaphore.signal()
		
		if count == 0 {
			return
		}
		
		encoder.setRenderPipelineState(pipeline)
		
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		encoder.setVertexBuffer(instances, offset: 0, index: 2)
		
		renderInstanced(primitive: lineSegmentPrimitive, count: count, into: encoder)
	}
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> LoddedBorderHash {
		return "\(regionHash)-\(lod)".hashValue
	}
}
