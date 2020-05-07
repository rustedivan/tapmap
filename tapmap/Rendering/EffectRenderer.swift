//
//  EffectRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-03-24.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd
import GLKit.GLKMatrix4

struct EffectUniforms {
	let mvpMatrix: simd_float4x4
	var progress: simd_float1
	var scaleMatrix: simd_float4x4
	var color: simd_float4
}

struct RegionEffect {
	let primitive: ArrayedRenderPrimitive
	let center: Vertex
	let startTime: Date
	let duration: TimeInterval
	var progress : Double {
		return Date().timeIntervalSince(startTime) / duration
	}
}

class EffectRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var runningEffects : [RegionEffect]
	var animating: Bool { get {
		return !runningEffects.isEmpty
	}}
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "effectVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "effectFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
		pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		runningEffects = []
	}
	
	func addOpeningEffect(for regionHash: RegionHash) {
		let streamer = GeometryStreamer.shared
		guard let tessellation = streamer.tessellation(for: regionHash, atLod: streamer.actualLodLevel) else { return }
		guard let primitive = streamer.renderPrimitive(for: regionHash) else { return }
		runningEffects.append(RegionEffect(primitive: primitive, center: tessellation.visualCenter, startTime: Date(), duration: 1.0))
	}
	
	func updatePrimitives() {
		runningEffects = runningEffects.filter {
			$0.startTime + $0.duration > Date()
		}
	}
	
	func renderWorld(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render opening effect")
		encoder.setRenderPipelineState(pipeline)
		
		var uniforms = EffectUniforms(mvpMatrix: projection, progress: 0.0, scaleMatrix: simd_float4x4(), color: simd_float4())
		for effect in runningEffects {
			let primitive = effect.primitive
			uniforms.color = simd_float4(primitive.color.r, primitive.color.g, primitive.color.b, 1.0)
			uniforms.progress = Float(effect.progress)
			
			// Construct matrix for scaling in place on top of `center`
			let scale = Float(1.0 + effect.progress * 0.5);
			uniforms.scaleMatrix = buildScaleAboutPointMatrix(scale: scale, center: effect.center)
			
			encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
			
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
}

