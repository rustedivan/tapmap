//
//  RegionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Metal
import GLKit
import simd

struct MapUniforms {
	let mvpMatrix: simd_float4x4
	var color: simd_float4
	var highlighted: simd_int1
}

class RegionRenderer {
	let pipeline: MTLRenderPipelineState
	var uniformBuffer: MTLBuffer
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "flatVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "flatFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
		} catch let error {
			print(error)
			exit(1)
		}
		
		var uniforms = MapUniforms(mvpMatrix: simd_float4x4(), color: simd_float4(), highlighted: simd_int1())
		uniformBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout.stride(ofValue: uniforms), options: .storageModeShared)!
		uniformBuffer.label = "RegionRenderer uniform block"
	}
	
	func renderWorld(visibleSet: Set<Int>, inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render world")
		// Collect all streamed-in primitives for the currently visible set of non-visited regions
		let renderPrimitives = visibleSet.compactMap { GeometryStreamer.shared.renderPrimitive(for: $0) }
		
		var uniforms = MapUniforms(mvpMatrix: projection, color: simd_float4(), highlighted: simd_int1())
		
		for primitive in renderPrimitives {
			uniforms.color = SIMD4<Float>(primitive.color.r, primitive.color.g, primitive.color.b, 1.0)
			uniforms.highlighted = AppDelegate.sharedUIState.selected(primitive.ownerHash) ? 1 : 0
			uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: 1 * MemoryLayout<MapUniforms>.stride)

			encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
			render(primitive: primitive)
		}
		
		encoder.popDebugGroup()
	}
}

