//
//  PostProcessingRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2022-08-07.
//  Copyright © 2022 Wildbrain. All rights reserved.
//

import Metal
import simd

// $ put time into frame uniform block
fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
	let screenSize: simd_float2
}

class PostProcessingRenderer {
	let pipeline: MTLRenderPipelineState
	var frameOffscreenTexture: [MTLTexture?]
	var screenSize: simd_float2
	
	let fullscreenQuadPrimitive: TexturedRenderPrimitive
	
	var frameSwitchSemaphore = DispatchSemaphore(value: 1)
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int, drawableSize: simd_float2) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "texturedVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "chromaticAberrationFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.frameOffscreenTexture = Array(repeating: nil, count: bufferCount)
			self.screenSize = drawableSize
			self.fullscreenQuadPrimitive = makeFullscreenQuadPrimitive(in: device)
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}
	
	func prepareFrame(offscreenTexture: MTLTexture, bufferIndex: Int) {
		frameSwitchSemaphore.wait()
		
		self.frameOffscreenTexture[bufferIndex] = offscreenTexture
		// $ write time
		
		frameSwitchSemaphore.signal()
	}
	
	func renderPostProcessing(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render postprocessing pass")
		defer {
			encoder.popDebugGroup()
		}
		
		frameSwitchSemaphore.wait()
		var frameUniforms = FrameUniforms(mvpMatrix: projection, screenSize: simd_float2(screenSize.x / 2.0, screenSize.y / 2.0))
			let offscreenTexture = self.frameOffscreenTexture[bufferIndex]
		frameSwitchSemaphore.signal()
		
		encoder.setRenderPipelineState(pipeline)
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setFragmentTexture(offscreenTexture, index: 0)
		
		render(primitive: fullscreenQuadPrimitive, into: encoder)
	}
}

fileprivate func makeFullscreenQuadPrimitive(in device: MTLDevice) -> TexturedRenderPrimitive {
	let vertices: [TexturedVertex] = [TexturedVertex(-0.5, -0.5, u: 0.0, v: 1.0), TexturedVertex(0.5, -0.5, u: 1.0, v: 1.0),
																		TexturedVertex(-0.5,  0.5, u: 0.0, v: 0.0), TexturedVertex(0.5,  0.5, u: 1.0, v: 0.0)]
	let indices: [UInt16] = [0, 1, 2, 1, 2, 3]
	
	return TexturedRenderPrimitive(	polygons: [vertices],	indices: [indices],
																	drawMode: .triangle, device: device,
																	color: Color(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
																	ownerHash: 0,	debugName: "Fullscreen quad primitive")
}
