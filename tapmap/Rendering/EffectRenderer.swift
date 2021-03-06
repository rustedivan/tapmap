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

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
}

fileprivate struct InstanceUniforms {
	var progress: simd_float1
	var scaleMatrix: simd_float4x4
	var color: simd_float4
}

struct RegionEffect {
	typealias EffectPrimitive = RenderPrimitive
	let primitive: EffectPrimitive
	let center: Vertex
	let startTime: Date
	let duration: TimeInterval
	var progress : Float {
		return Float(Date().timeIntervalSince(startTime) / duration)
	}
}

class EffectRenderer {
	typealias EffectPrimitive = RegionEffect.EffectPrimitive
	typealias RenderList = ContiguousArray<EffectPrimitive>
	static let kMaxSimultaneousEffects = 8
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]
	
	var runningEffects : [RegionEffect]

	var renderLists : [RenderList]
	var frameSelectSemaphore = DispatchSemaphore(value: 1)
	
	var animating: Bool { get {
		return !runningEffects.isEmpty
	}}
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.sampleCount = 4
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "effectVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "effectFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
		pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		pipelineDescriptor.vertexBuffers[1].mutability = .immutable
		pipelineDescriptor.vertexBuffers[2].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.renderLists = Array(repeating: RenderList(), count: bufferCount)
			self.instanceUniforms = (0..<bufferCount).map { _ in
				return device.makeBuffer(length: EffectRenderer.kMaxSimultaneousEffects * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
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
	
	func prepareFrame(bufferIndex: Int) {
		runningEffects = runningEffects.filter {
			$0.startTime + $0.duration > Date()
		}
		
		let frameRenderList = RenderList(runningEffects.map { $0.primitive })
		
		var fx = Array<InstanceUniforms>()
		fx.reserveCapacity(runningEffects.count)
		for effect in runningEffects {
			// Construct matrix for "scaling in place" on top of `center`
			let scale = Float(1.0 + effect.progress * 0.5);
			let sipMatrix = buildScaleAboutPointMatrix(scale: scale, center: effect.center)
			
			let u = InstanceUniforms(progress: effect.progress,
															 scaleMatrix: sipMatrix,
															 color: effect.primitive.color.vector)
			fx.append(u)
		}
		
		frameSelectSemaphore.wait()
			renderLists[bufferIndex] = frameRenderList
			instanceUniforms[bufferIndex].contents().copyMemory(from: fx, byteCount: MemoryLayout<InstanceUniforms>.stride * fx.count)
		frameSelectSemaphore.signal()
	}
	
	func renderWorld(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render opening effect")
		encoder.setRenderPipelineState(pipeline)
		
		frameSelectSemaphore.wait()
			var frameUniforms = FrameUniforms(mvpMatrix: projection)
			let renderList = renderLists[bufferIndex]
			let uniforms = instanceUniforms[bufferIndex]
		frameSelectSemaphore.signal()
		
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setVertexBuffer(uniforms, offset: 0, index: 2)
		
		var instanceCursor = 0
		for primitive in renderList {
			encoder.setVertexBufferOffset(instanceCursor, index: 2)
			render(primitive: primitive, into: encoder)
			
			instanceCursor += MemoryLayout<InstanceUniforms>.stride
		}
		
		encoder.popDebugGroup()
	}
}

