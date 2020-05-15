//
//  SelectionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd

struct SelectionUniforms {
	let mvpMatrix: simd_float4x4
	let width: simd_float1
	let color: simd_float4
}

class SelectionRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var outlinePrimitive: OutlineRenderPrimitive?
	var outlineWidth: Float
	var lodLevel: Int
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "selectionVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "selectionFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		outlineWidth = 0.0
		lodLevel = GeometryStreamer.shared.wantedLodLevel
	}
	
	func select(regionHash: RegionHash) {
		let streamer = GeometryStreamer.shared
		guard let tessellation = streamer.tessellation(for: regionHash, atLod: streamer.actualLodLevel) else { return }
		
		let thinOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: 0.2, outerExtent: 0.5) }
		let countourVertices = tessellation.contours.map({$0.vertices})
		let outlineGeometry: RegionContours = countourVertices.map(thinOutline)
		
		outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																							device: device,
																							ownerHash: regionHash,
																							debugName: "Selection contours")
	}
	
	func clear() {
		outlinePrimitive = nil
	}
	
	func updateStyle(zoomLevel: Float) {
		outlineWidth = 1.0 / zoomLevel
		
		if let selectionHash = outlinePrimitive?.ownerHash, lodLevel != GeometryStreamer.shared.actualLodLevel {
			select(regionHash: selectionHash)
			lodLevel = GeometryStreamer.shared.actualLodLevel
		}
	}
	
	func renderSelection(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		guard let primitive = outlinePrimitive else { return }
		encoder.pushDebugGroup("Render outlines")
		encoder.setRenderPipelineState(pipeline)
		
		var uniforms = SelectionUniforms(mvpMatrix: projection, width: outlineWidth, color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0).vector)
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		
		render(primitive: primitive, into: encoder)
	
		encoder.popDebugGroup()
	}
}
