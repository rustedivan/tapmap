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
	let alignmentIn: simd_float1
	let alignmentOut: simd_float1
	let color: simd_float4
}

fileprivate let kMaxLineSegments = 65535

class SelectionRenderer {
	let device: MTLDevice
	let linePipeline: MTLRenderPipelineState
	let joinPipeline: MTLRenderPipelineState
	
	var lineSegmentPrimitive: LineSegmentPrimitive
	var joinSegmentPrimitive: LineSegmentPrimitive
	var frameSelectSemaphore = DispatchSemaphore(value: 1)

	var lineSegmentsHighwaterMark: Int = 0
	
	let lineInstanceUniforms: [MTLBuffer]
	let joinInstanceUniforms: [MTLBuffer]
	var frameLineSegmentCount: [Int] = []
	
	var outlineWidth: Float
	let alignmentIn: Float = 0.0
	let alignmentOut: Float = 1.0
	var lodLevel: Int
	var selectionHash: RegionHash?
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let linePipelineDescriptor = MTLRenderPipelineDescriptor()
		linePipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "lineVertex")
		linePipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "lineFragment")
		linePipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		linePipelineDescriptor.vertexBuffers[0].mutability = .immutable
		linePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		linePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		linePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		linePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		linePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		
		let joinPipelineDescriptor = MTLRenderPipelineDescriptor()
		joinPipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "bevelVertex")
		joinPipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "bevelFragment")
		joinPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		joinPipelineDescriptor.vertexBuffers[0].mutability = .immutable
		joinPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		joinPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		joinPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		joinPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		joinPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		
		do {
			try linePipeline = device.makeRenderPipelineState(descriptor: linePipelineDescriptor)
			try joinPipeline = device.makeRenderPipelineState(descriptor: joinPipelineDescriptor)
			self.device = device
			self.frameLineSegmentCount = Array(repeating: 0, count: bufferCount)

			self.lineInstanceUniforms = (0..<bufferCount).map { bufferIndex in
				device.makeBuffer(length: kMaxLineSegments * MemoryLayout<LineInstanceUniforms>.stride, options: .storageModeShared)!
			}
			self.joinInstanceUniforms = (0..<bufferCount).map { bufferIndex in
				device.makeBuffer(length: kMaxLineSegments * MemoryLayout<JoinInstanceUniforms>.stride, options: .storageModeShared)!
			}
	
			self.lineSegmentPrimitive = makeLineSegmentPrimitive(in: device, inside: alignmentIn, outside: alignmentOut)
			self.joinSegmentPrimitive = makeBevelJoinPrimitive(in: device, width: abs(alignmentIn - alignmentOut))
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
		
		// $ cull line geometry against viewbox
		let selectionLineBuffer = generateContourLineGeometry(contours: tessellation.contours)
		guard selectionLineBuffer.count < kMaxLineSegments else {
			fatalError("line segment buffer blew out at \(selectionLineBuffer.count) vertices (max \(kMaxLineSegments))")
		}
		let selectionJoinBuffer = generateContourJoinGeometry(contours: tessellation.contours)
		
		if lodLevel != GeometryStreamer.shared.actualLodLevel {
			lodLevel = GeometryStreamer.shared.actualLodLevel
			print("Selection lod changed to \(lodLevel)")
		}
		
		self.outlineWidth = 1.5 / zoomLevel

		frameSelectSemaphore.wait()
			self.frameLineSegmentCount[bufferIndex] = selectionLineBuffer.count
			self.lineInstanceUniforms[bufferIndex].contents().copyMemory(from: selectionLineBuffer, byteCount: MemoryLayout<LineInstanceUniforms>.stride * selectionLineBuffer.count)
			self.joinInstanceUniforms[bufferIndex].contents().copyMemory(from: selectionJoinBuffer, byteCount: MemoryLayout<JoinInstanceUniforms>.stride * selectionJoinBuffer.count)
			if selectionLineBuffer.count > lineSegmentsHighwaterMark {
				lineSegmentsHighwaterMark = selectionLineBuffer.count
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
																	 alignmentIn: alignmentIn,
																	 alignmentOut: alignmentOut,
																	 color: Color(r: 0.1, g: 0.1, b: 0.2, a: 0.7).vector)
			let lineInstances = lineInstanceUniforms[bufferIndex]
			let joinInstances = joinInstanceUniforms[bufferIndex]
			let count = frameLineSegmentCount[bufferIndex]
		frameSelectSemaphore.signal()
		
		if count == 0 {
			return
		}
		
		encoder.setRenderPipelineState(linePipeline)
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		encoder.setVertexBuffer(lineInstances, offset: 0, index: 2)
		renderInstanced(primitive: lineSegmentPrimitive, count: count, into: encoder)
		
		encoder.setRenderPipelineState(joinPipeline)
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		encoder.setVertexBuffer(joinInstances, offset: 0, index: 2)
		renderInstanced(primitive: joinSegmentPrimitive, count: count, into: encoder)
	}
}

