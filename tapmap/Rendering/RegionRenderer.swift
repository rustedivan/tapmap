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
	let pipeline: MTLRenderPipelineState
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "mapVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "mapFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}
	
	func renderWorld(visibleSet: Set<Int>, inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render world")
		encoder.setRenderPipelineState(pipeline)

		// Collect all streamed-in primitives for the currently visible set of non-visited regions
		let renderPrimitives = visibleSet.compactMap { GeometryStreamer.shared.renderPrimitive(for: $0) }
		
		var uniforms = MapUniforms(mvpMatrix: projection,
															 color: simd_float4(),
															 highlighted: simd_int1())
		
		for primitive in renderPrimitives {
			uniforms.color = simd_float4(primitive.color.r, primitive.color.g, primitive.color.b, 1.0)
			uniforms.highlighted = AppDelegate.sharedUIState.selected(primitive.ownerHash) ? 1 : 0
			encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
}

