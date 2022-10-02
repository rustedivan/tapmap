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

fileprivate let kMaxLineSegments = 16384

class SelectionRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var lineSegmentPrimitive: LineSegmentPrimitive
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
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "lineVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "lineFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.frameLineSegmentCount = Array(repeating: 0, count: bufferCount)

			self.instanceUniforms = (0..<bufferCount).map { bufferIndex in
				device.makeBuffer(length: kMaxLineSegments * MemoryLayout<LineInstanceUniforms>.stride, options: .storageModeShared)!
			}
			self.lineSegmentPrimitive = makeLineSegmentPrimitive(in: device, inside: 0.0, outside: -1.0)
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
			print("Selection lod changed to \(lodLevel)")
		}
		self.outlineWidth = 3.0 / zoomLevel

		frameSelectSemaphore.wait()
			self.frameLineSegmentCount[bufferIndex] = selectionBuffer.count
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: selectionBuffer, byteCount: MemoryLayout<LineInstanceUniforms>.stride * selectionBuffer.count)
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

