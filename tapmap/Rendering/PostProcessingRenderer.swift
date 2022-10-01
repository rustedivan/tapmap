//
//  PostProcessingRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2022-08-07.
//  Copyright © 2022 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let timestamp: Float
}

class PostProcessingRenderer {
	let pipeline: MTLRenderPipelineState
	var frameOffscreenTexture: [MTLTexture?]
	
	let fullscreenQuadPrimitive: TexturedRenderPrimitive
	let startTime: Date
	
	var frameSwitchSemaphore = DispatchSemaphore(value: 1)
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int, drawableSize: simd_float2) {
		startTime = Date()
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "texturedVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "chromaticAberrationFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.frameOffscreenTexture = Array(repeating: nil, count: bufferCount)
			self.fullscreenQuadPrimitive = makeFullscreenQuadPrimitive(in: device)
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}
	
	func prepareFrame(offscreenTexture: MTLTexture, bufferIndex: Int) {
		frameSwitchSemaphore.wait()
			self.frameOffscreenTexture[bufferIndex] = offscreenTexture
		frameSwitchSemaphore.signal()
	}
	
	func renderPostProcessing(inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render postprocessing pass")
		defer {
			encoder.popDebugGroup()
		}
		
		let frameTime = Float(Date().timeIntervalSince(startTime))
		frameSwitchSemaphore.wait()
		var frameUniforms = FrameUniforms(timestamp: frameTime)
			let offscreenTexture = self.frameOffscreenTexture[bufferIndex]
		frameSwitchSemaphore.signal()
		
		encoder.setRenderPipelineState(pipeline)
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setFragmentTexture(offscreenTexture, index: 0)
		encoder.setFragmentBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		
		render(primitive: fullscreenQuadPrimitive, into: encoder)
	}
}

fileprivate func makeFullscreenQuadPrimitive(in device: MTLDevice) -> TexturedRenderPrimitive {
	let vertices: [TexturedVertex] = [TexturedVertex(-1.0, -1.0, u: 0.0, v: 1.0), TexturedVertex(1.0, -1.0, u: 1.0, v: 1.0),
																		TexturedVertex(-1.0,  1.0, u: 0.0, v: 0.0), TexturedVertex(1.0,  1.0, u: 1.0, v: 0.0)]
	let indices: [UInt16] = [0, 1, 2, 1, 2, 3]
	
	return TexturedRenderPrimitive(	polygons: [vertices],	indices: [indices],
																	drawMode: .triangle, device: device,
																	color: Color(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
																	ownerHash: 0,	debugName: "Fullscreen quad primitive")
}
