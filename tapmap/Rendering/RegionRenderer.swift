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
	typealias RegionPrimitive = IndexedRenderPrimitive<Vertex>
	typealias RenderList = ContiguousArray<RegionPrimitive>

	static let kMaxVisibleRegions = 5000
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]
	var renderLists: [RenderList] = []
	var renderListSemaphore = DispatchSemaphore(value: 1)
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "mapVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "mapFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		pipelineDescriptor.vertexBuffers[1].mutability = .immutable
		pipelineDescriptor.vertexBuffers[2].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.renderLists = (0..<bufferCount).map { _ in
				return ContiguousArray()	// $ Replace all CA's with local RenderList
			}
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
		
		let frameRenderList = ContiguousArray(visibleSet.compactMap { regionHash in
														return GeometryStreamer.shared.renderPrimitive(for: regionHash, streamIfMissing: true)
													})
		
		renderListSemaphore.wait()
			renderLists[bufferIndex] = frameRenderList
		renderListSemaphore.signal()
		
		let highlightedRegionHash = AppDelegate.sharedUIState.selectedRegionHash
		var styles = Array<InstanceUniforms>()
		styles.reserveCapacity(visibleSet.count)
		for region in renderLists[bufferIndex] {
			var c = region.color.vector
			if region.ownerHash == highlightedRegionHash {
				c.x = min(c.x - 0.3, 1.0)
				c.y = min(c.y - 0.3, 1.0)
				c.z = min(c.z - 0.3, 1.0)
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
		encoder.setVertexBuffer(self.instanceUniforms[bufferIndex], offset: 0, index: 2)

		renderListSemaphore.wait()
			let renderList = self.renderLists[bufferIndex]
		renderListSemaphore.signal()
		var instanceCursor = 0
		for primitive in renderList {
			encoder.setVertexBufferOffset(instanceCursor, index: 2)
			render(primitive: primitive, into: encoder)
			
			instanceCursor += MemoryLayout<InstanceUniforms>.stride
		}
		
		encoder.popDebugGroup()
	}
}

