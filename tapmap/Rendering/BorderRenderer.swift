//
//  BorderRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-04-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
	let width: simd_float1
	var color: simd_float4
}

fileprivate struct InstanceUniforms {
	var a: simd_float2
	var b: simd_float2
}

struct BorderContour {
	let contours: [VertexRing]
}

class BorderRenderer<RegionType> {
	typealias RenderList = ContiguousArray<BorderContour>
	typealias LoddedBorderHash = Int

	let rendererLabel: String
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let maxVisibleLineSegments: Int
	var lineSegmentsHighwaterMark: Int = 0
	var borderContours: [LoddedBorderHash : BorderContour]
	var frameSelectSemaphore = DispatchSemaphore(value: 1)
	let lineSegmentPrimitive: BaseRenderPrimitive<Vertex>!
	let instanceUniforms: [MTLBuffer]
	var frameLineSegmentCount: [Int] = []
	
	var borderScale: Float
	var width: Float = 1.0
	var color: simd_float4 = simd_float4(0.0, 0.0, 0.0, 1.0)
	
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int, maxSegments: Int, label: String) {
		borderScale = 0.0
		
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.sampleCount = 4
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "borderVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "borderFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
				
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.rendererLabel = label
			self.device = device
			self.frameLineSegmentCount = Array(repeating: 0, count: bufferCount)
			self.maxVisibleLineSegments = maxSegments	// Determined experimentally and rounded up a lot
			self.instanceUniforms = (0..<bufferCount).map { bufferIndex in
				device.makeBuffer(length: maxSegments * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
			
			self.lineSegmentPrimitive = makeLineSegmentPrimitive(in: device)
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		borderContours = [:]
		
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
	}
	
	func setStyle(innerWidth: Float, outerWidth: Float, color: simd_float4) {
		self.width = innerWidth
		self.color = color
	}

	func prepareFrame(borderedRegions: [Int : RegionType], zoom: Float, zoomRate: Float, bufferIndex: Int) {
		let streamer = GeometryStreamer.shared
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		// $ Only need to update if the data or viewbox are dirty
		
		// Stream in any missing geometries at the wanted LOD level
		for borderHash in borderedRegions.keys {
			let loddedBorderHash = borderHashLodKey(borderHash, atLod: lodLevel)
			if borderContours[loddedBorderHash] == nil {
				borderLodMiss = true
				
				guard let tessellation = streamer.tessellation(for: borderHash, atLod: lodLevel, streamIfMissing: true) else {
					return
				}
				
				borderContours[loddedBorderHash] = BorderContour(contours: tessellation.contours)
			}
		}

		// Update the LOD level if we have all its geometries
		if !borderLodMiss && actualBorderLod != streamer.wantedLodLevel {
			actualBorderLod = streamer.wantedLodLevel
		}
		
		// $ Move this to backthread
		
		// Collect the vertex rings for the visible set of borders
		let frameRenderList = RenderList(borderedRegions.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderContours[loddedKey]
		})
		
		let regionContours = frameRenderList.flatMap { $0.contours }
		
		// Generate all the vertices in all the outlines
		let borderBuffer = generateContourCollectionGeometry(contours: regionContours)
		guard borderBuffer.count < maxVisibleLineSegments else {
			fatalError("line segment buffer blew out at \(borderBuffer.count) vertices (max \(maxVisibleLineSegments))")
		}

		let borderZoom = zoom / (1.0 - zoomRate + zoomRate * Stylesheet.shared.borderZoomBias.value)	// Borders become wider at closer zoom levels
		frameSelectSemaphore.wait()
			self.borderScale = 1.0 / borderZoom
			self.frameLineSegmentCount[bufferIndex] = borderBuffer.count
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: borderBuffer, byteCount: MemoryLayout<InstanceUniforms>.stride * borderBuffer.count)
			if borderBuffer.count > lineSegmentsHighwaterMark {
				lineSegmentsHighwaterMark = borderBuffer.count
				print("\(rendererLabel) used a max of \(lineSegmentsHighwaterMark) line segments.")
			}
		frameSelectSemaphore.signal()
	}

	func renderBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render \(rendererLabel)'s borders")
		defer {
			encoder.popDebugGroup()
		}
		
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection,
																	 width: width * borderScale,
																	 color: color)
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
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> LoddedBorderHash {
		return "\(regionHash)-\(lod)".hashValue
	}
}

func makeLineSegmentPrimitive(in device: MTLDevice) -> RenderPrimitive {
	// The 95/5 values place borders at 95% inward, with some small overlap outward
	let vertices: [Vertex] = [
		Vertex(0.0, -0.05),
		Vertex(1.0, -0.05),
		Vertex(1.0,  0.95),
		Vertex(0.0,  0.95)
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
