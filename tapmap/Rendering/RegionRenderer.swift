//
//  RegionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Metal
import simd

struct MapUniforms {
	let mvpMatrix: simd_float4x4
	var color: simd_float4
	var highlighted: simd_int1
}

class RegionRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	var highlightedRegionHash: Int = 0
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "mapVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "mapFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}
	
	func prepareFrame(visibleSet: Set<RegionHash>) {
		for regionHash in visibleSet {
			_ = GeometryStreamer.shared.renderPrimitive(for: regionHash, streamIfMissing: true)
		}
		highlightedRegionHash = AppDelegate.sharedUIState.selectedRegionHash
	}
	
	func renderWorld(visibleSet: Set<RegionHash>, inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render world")
		encoder.setRenderPipelineState(pipeline)

		// Collect all streamed-in primitives for the currently visible set of non-visited regions
		let renderPrimitives = visibleSet.compactMap { GeometryStreamer.shared.renderPrimitive(for: $0, streamIfMissing: false) }
		
		var uniforms = MapUniforms(mvpMatrix: projection,
															 color: simd_float4(),
															 highlighted: simd_int1())
		
		for primitive in renderPrimitives {
			uniforms.color = simd_float4(primitive.color.r, primitive.color.g, primitive.color.b, 1.0)
			uniforms.highlighted = (primitive.ownerHash == highlightedRegionHash) ? 1 : 0
			encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
}

