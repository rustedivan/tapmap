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

fileprivate struct InstanceUniforms {
	var a: simd_float2
	var b: simd_float2
}

fileprivate let kMaxLineSegments = 4096

class SelectionRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var lineSegmentPrimitive: BaseRenderPrimitive<Vertex>!
	var frameSelectSemaphore = DispatchSemaphore(value: 1)

	var lineSegmentsHighwaterMark: Int = 0
	
	let instanceUniforms: [MTLBuffer]
	var frameLineSegmentCount: [Int] = []

	var outlineWidth: Float
	var lodLevel: Int
	var selectionHash: RegionHash?
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "selectionVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "selectionFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.frameLineSegmentCount = Array(repeating: 0, count: bufferCount)

			self.instanceUniforms = (0..<bufferCount).map { bufferIndex in
				device.makeBuffer(length: kMaxLineSegments * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
			self.lineSegmentPrimitive = makeLineSegmentPrimitive(in: device)
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		outlineWidth = 0.0
		lodLevel = GeometryStreamer.shared.wantedLodLevel
	}

	func clear() {
		selectionHash = nil
	}
	
	func prepareFrame(zoomLevel: Float, bufferIndex: Int) {
		let streamer = GeometryStreamer.shared
		guard let selectionHash = selectionHash else {
			return
		}
		guard let tessellation = streamer.tessellation(for: selectionHash, atLod: lodLevel, streamIfMissing: true) else {
			return
		}

		let selectionBuffer = generateContourCollectionGeometry(contours: tessellation.contours)
		guard selectionBuffer.count < kMaxLineSegments else {
			fatalError("line segment buffer blew out at \(selectionBuffer.count) vertices (max \(kMaxLineSegments))")
		}
		
		if lodLevel != GeometryStreamer.shared.actualLodLevel {
			lodLevel = GeometryStreamer.shared.actualLodLevel
		}
		self.outlineWidth = 1.0 / zoomLevel

		frameSelectSemaphore.wait()
			self.frameLineSegmentCount[bufferIndex] = selectionBuffer.count
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: selectionBuffer, byteCount: MemoryLayout<InstanceUniforms>.stride * selectionBuffer.count)
			if selectionBuffer.count > lineSegmentsHighwaterMark {
				lineSegmentsHighwaterMark = selectionBuffer.count
				print("Selection renderer used a max of \(lineSegmentsHighwaterMark) line segments.")
			}
		frameSelectSemaphore.signal()
	}
	
	func renderSelection(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render selection")
		defer {
			encoder.popDebugGroup()
		}
	
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection,
																	 width: self.outlineWidth,
																	 color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0).vector)
			let instances = instanceUniforms[bufferIndex]
			let count = frameLineSegmentCount[bufferIndex]
		frameSelectSemaphore.signal()
		
		if count == 0 {
			return
		}
		
		encoder.setRenderPipelineState(pipeline)
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		encoder.setVertexBuffer(instances, offset: 0, index: 2)
		
		renderInstanced(primitive: lineSegmentPrimitive, count: count, into: encoder)
	}
}

fileprivate func makeLineSegmentPrimitive(in device: MTLDevice) -> RenderPrimitive {
	let vertices: [Vertex] = [
		Vertex(0.0, 0.0),
		Vertex(1.0, 0.0),
		Vertex(1.0, 1.0),
		Vertex(0.0, 1.0)
	]
	let indices: [UInt16] = [
		0, 1, 2, 0, 2, 3
	]
	
	return RenderPrimitive(	polygons: [vertices],
													indices: [indices],
													drawMode: .triangle,
													device: device,
													color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0),
													ownerHash: 0,
													debugName: "Line segment primitive")
}

fileprivate func generateContourCollectionGeometry(contours: [VertexRing]) -> Array<InstanceUniforms> {
	let segmentCount = contours.reduce(0) { $0 + $1.vertices.count }
	var vertices = Array<InstanceUniforms>()
	vertices.reserveCapacity(segmentCount)
	for contour in contours {
		for i in 0..<contour.vertices.count - 1 {
			let a = contour.vertices[i]
			let b = contour.vertices[i + 1]
			vertices.append(InstanceUniforms(
				a: simd_float2(x: a.x, y: a.y),
				b: simd_float2(x: b.x, y: b.y)
			))
		}
	}
	return vertices
}
