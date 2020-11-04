//
//  SelectionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
	let width: simd_float1
	let color: simd_float4
}

class SelectionRenderer {
	typealias SelectionPrimitive = FixedScaleRenderPrimitive
	typealias RenderList = ContiguousArray<SelectionPrimitive>
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var outlinePrimitive: SelectionPrimitive?
	var renderList: RenderList
	var frameSelectSemaphore = DispatchSemaphore(value: 1)
	
	var outlineWidth: Float
	var lodLevel: Int
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.sampleCount = 4
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "selectionVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "selectionFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		pipelineDescriptor.vertexBuffers[1].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.renderList = RenderList()	// SelectionRenderer does not need to triple-buffer
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		outlineWidth = 0.0
		lodLevel = GeometryStreamer.shared.wantedLodLevel
	}
	
	func updatePrimitive(selectedRegionHash: RegionHash) {
		let streamer = GeometryStreamer.shared
		guard let tessellation = streamer.tessellation(for: selectedRegionHash, atLod: streamer.actualLodLevel) else { return }
		
		let thinOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: 0.2, outerExtent: 0.5) }
		let countourVertices = tessellation.contours.map({$0.vertices})
		let outlineGeometry: RegionContours = countourVertices.map(thinOutline)
		
		var cursor = 0
		var stackedIndices: [[UInt16]] = []
		for outline in outlineGeometry {
			let indices = 0..<UInt16(outline.count)
			let stackedRing = indices.map { $0 + UInt16(cursor) }
			stackedIndices.append(stackedRing)
			cursor += outline.count
		}
		
		outlinePrimitive = SelectionPrimitive(polygons: outlineGeometry,
																					indices: stackedIndices,
																					drawMode: .triangleStrip,
																					device: device,
																					color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0),
																					ownerHash: selectedRegionHash,
																					debugName: "Selection contours")
	}
	
	func clear() {
		outlinePrimitive = nil
	}
	
	func prepareFrame(zoomLevel: Float) {
		
		if let selectionHash = outlinePrimitive?.ownerHash, lodLevel != GeometryStreamer.shared.actualLodLevel {
			updatePrimitive(selectedRegionHash: selectionHash)
			lodLevel = GeometryStreamer.shared.actualLodLevel
		}
		
		frameSelectSemaphore.wait()
			self.outlineWidth = 1.0 / zoomLevel
			self.renderList = outlinePrimitive != nil ? [outlinePrimitive!] : []
		frameSelectSemaphore.signal()
	}
	
	func renderSelection(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		guard !renderList.isEmpty else { return }
	
		encoder.pushDebugGroup("Render outlines")
		encoder.setRenderPipelineState(pipeline)
	
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection, width: self.outlineWidth, color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0).vector)
		frameSelectSemaphore.signal()
		
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		
		for primitive in renderList {
			render(primitive: primitive, into: encoder)
		}
	
		encoder.popDebugGroup()
	}
}
