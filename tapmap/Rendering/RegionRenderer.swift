//
//  RegionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
}

fileprivate struct InstanceUniforms {
	var color: simd_float4
}

class RegionRenderer {
	static let kMaxVisibleRegions = 5000
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]
	var renderList: [IndexedRenderPrimitive<Vertex>] = []
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "mapVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "mapFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.instanceUniforms = (0..<bufferCount).map { _ in
				return device.makeBuffer(length: RegionRenderer.kMaxVisibleRegions * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}
	
	func prepareFrame(visibleSet: Set<RegionHash>, bufferIndex: Int) {
		// Collect all streamed-in primitives for the currently visible set of non-visited regions
		// Store it locally until it's time to render, because geometryStreamer is allowed to change
		// its list of available primitives at any time
		renderList = visibleSet.compactMap { regionHash in
			return GeometryStreamer.shared.renderPrimitive(for: regionHash, streamIfMissing: true)
		}
		
		let highlightedRegionHash = AppDelegate.sharedUIState.selectedRegionHash
		var styles = Array<InstanceUniforms>()
		styles.reserveCapacity(visibleSet.count)
		for region in renderList {
			var c = region.color.vector
			if region.ownerHash == highlightedRegionHash {
				c.x = max(c.x + 0.3, 1.0)
				c.y = max(c.y + 0.3, 1.0)
				c.z = max(c.z + 0.3, 1.0)
			}
			
			let u = InstanceUniforms(color: c)	// $ Look up in style map
			styles.append(u)
		}
		instanceUniforms[bufferIndex].contents().copyMemory(from: styles,
																												byteCount: MemoryLayout<InstanceUniforms>.stride * styles.count)
	}
	
	func renderWorld(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render world")
		encoder.setRenderPipelineState(pipeline)
		
		var frameUniforms = FrameUniforms(mvpMatrix: projection)
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setVertexBuffer(instanceUniforms[bufferIndex], offset: 0, index: 2)

		var instanceCursor = 0
		for primitive in renderList {
			encoder.setVertexBufferOffset(instanceCursor, index: 2)
			render(primitive: primitive, into: encoder)
			
			instanceCursor += MemoryLayout<InstanceUniforms>.stride
		}
		
		encoder.popDebugGroup()
	}
}

