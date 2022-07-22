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
	let widthInner: simd_float1
	let widthOuter: simd_float1
	var color: simd_float4
}

fileprivate struct InstanceUniforms {
	var vertex: simd_float2
}

struct BorderContour {
	let contours: [VertexRing]
}

class BorderRenderer {
	typealias RenderList = ContiguousArray<BorderContour>
	typealias LoddedBorderHash = Int

	static let kMaxVisibleLineSegments = 300000	// Established via high-water mark testing: ~200k is the highest observed.

	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var borderContours: [LoddedBorderHash : BorderContour]
	var frameSelectSemaphore = DispatchSemaphore(value: 1)
	let lineSegmentPrimitive: BaseRenderPrimitive<Vertex>!
	let continentInstanceUniforms: [MTLBuffer]
	var continentFrameLineSegmentCount: [Int] = []
	let countryInstanceUniforms: [MTLBuffer]
	var countryFrameLineSegmentCount: [Int] = []
	let provinceInstanceUniforms: [MTLBuffer]
	var provinceFrameLineSegmentCount: [Int] = []
	
	var borderScale: Float
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	let borderQueue: DispatchQueue
	let publishQueue: DispatchQueue

	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
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
			self.device = device
			self.continentFrameLineSegmentCount = Array(repeating: 0, count: bufferCount)
			self.continentInstanceUniforms = (0..<bufferCount).map { bufferIndex in	// $ If we're not drawing continents, this buffer can be omitted
				let buffer = device.makeBuffer(length: BorderRenderer.kMaxVisibleLineSegments * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
				buffer.label = "Continent border uniform buffer @ \(bufferIndex)"
				return buffer
			}
			self.countryFrameLineSegmentCount = Array(repeating: 0, count: bufferCount)
			self.countryInstanceUniforms = (0..<bufferCount).map { bufferIndex in
				let buffer = device.makeBuffer(length: BorderRenderer.kMaxVisibleLineSegments * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
				buffer.label = "Country border uniform buffer @ \(bufferIndex)"
				return buffer
			}
			self.provinceFrameLineSegmentCount = Array(repeating: 0, count: bufferCount)
			self.provinceInstanceUniforms = (0..<bufferCount).map { bufferIndex in
				let buffer = device.makeBuffer(length: BorderRenderer.kMaxVisibleLineSegments * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
				buffer.label = "Province border uniform buffer @ \(bufferIndex)"
				return buffer
			}
			
			self.lineSegmentPrimitive = makeLineSegmentPrimitive(in: device)
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		borderContours = [:]
		
		borderQueue = DispatchQueue(label: "Border construction", qos: .userInitiated, attributes: .concurrent)
		publishQueue = DispatchQueue(label: "Border delivery")
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
	}
	
	func prepareFrame(borderedContinents: GeoContinentMap, borderedCountries: GeoCountryMap, borderedProvinces: GeoProvinceMap, zoom: Float, zoomRate: Float, bufferIndex: Int) {
		let streamer = GeometryStreamer.shared
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		// $ Only need to update if the data or viewbox are dirty
		
		// Stream in any missing geometries at the wanted LOD level
		let updateSet: [Int] = Array(borderedContinents.keys) + Array(borderedCountries.keys) + Array(borderedProvinces.keys)
		for borderHash in updateSet {
			let loddedBorderHash = borderHashLodKey(borderHash, atLod: lodLevel)
			if borderContours[loddedBorderHash] == nil {
				borderLodMiss = true
				
				guard let tessellation = streamer.tessellation(for: borderHash, atLod: lodLevel, streamIfMissing: true) else {
					return
				}
				
				var contourRings = tessellation.contours
				if borderedContinents[borderHash] != nil && !contourRings.isEmpty {
					contourRings = Array(contourRings[0..<1])	// Continents should only display their outer contour
				}

				borderContours[loddedBorderHash] = BorderContour(contours: contourRings)
			}
		}

		// Update the LOD level if we have all its geometries
		if !borderLodMiss && actualBorderLod != streamer.wantedLodLevel {
			actualBorderLod = streamer.wantedLodLevel
		}
		let continentOutlineLod = max(actualBorderLod, 0)	// $ Turn up the limit once border width is under control (set min/max outline width and ramp between )
		
		// $ Move this to backthread
		
		// Collect the vertex rings for the visible set of borders
		let frameContinentRenderList = RenderList(borderedContinents.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: continentOutlineLod)
			return borderContours[loddedKey]
		})

		let frameCountryRenderList = RenderList(borderedCountries.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderContours[loddedKey]
		})

		let frameProvinceRenderList = RenderList(borderedProvinces.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderContours[loddedKey]
		})
		
		let continentContours = frameContinentRenderList.flatMap { $0.contours }
		let countryContours = frameCountryRenderList.flatMap { $0.contours }
		let provinceContours = frameProvinceRenderList.flatMap { $0.contours }
		
		// Generate all the vertices in all the outlines
		let continentBuffer = generateContourCollectionGeometry(contours: continentContours)
		guard continentBuffer.count < BorderRenderer.kMaxVisibleLineSegments else {
			fatalError("continent line segment buffer blew out at \(continentBuffer.count) vertices (max \(BorderRenderer.kMaxVisibleLineSegments))")
		}

		let countryBuffer = generateContourCollectionGeometry(contours: countryContours)
		guard countryBuffer.count < BorderRenderer.kMaxVisibleLineSegments else {
			fatalError("country line segment buffer blew out at \(countryBuffer.count) vertices (max \(BorderRenderer.kMaxVisibleLineSegments))")
		}
		
		let provinceBuffer = generateContourCollectionGeometry(contours: provinceContours)
		guard provinceBuffer.count < BorderRenderer.kMaxVisibleLineSegments else {
			fatalError("province line segment buffer blew out at \(provinceBuffer.count) vertices (max \(BorderRenderer.kMaxVisibleLineSegments))")
		}

		let borderZoom = zoom / (1.0 - zoomRate + zoomRate * Stylesheet.shared.borderZoomBias.value)	// Borders become wider at closer zoom levels
		frameSelectSemaphore.wait()
			self.borderScale = 1.0 / borderZoom
			self.continentFrameLineSegmentCount[bufferIndex] = continentBuffer.count
			self.continentInstanceUniforms[bufferIndex].contents().copyMemory(from: continentBuffer, byteCount: MemoryLayout<InstanceUniforms>.stride * continentBuffer.count)
			self.countryInstanceUniforms[bufferIndex].contents().copyMemory(from: countryBuffer, byteCount: MemoryLayout<InstanceUniforms>.stride * countryBuffer.count)
			self.countryFrameLineSegmentCount[bufferIndex] = countryBuffer.count
			self.provinceInstanceUniforms[bufferIndex].contents().copyMemory(from: provinceBuffer, byteCount: MemoryLayout<InstanceUniforms>.stride * provinceBuffer.count)
			self.provinceFrameLineSegmentCount[bufferIndex] = provinceBuffer.count
		frameSelectSemaphore.signal()
	}
	
	func renderContinentBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render continent borders")
		encoder.setRenderPipelineState(pipeline)
		
//		frameSelectSemaphore.wait()
//			var frameUniforms = FrameUniforms(mvpMatrix: projection,
//																				widthInner: Stylesheet.shared.continentBorderWidthInner.value * borderScale,
//																				widthOuter: Stylesheet.shared.continentBorderWidthOuter.value * borderScale,
//																				color: Color(r: 1.0, g: 0.5, b: 0.7, a: 1.0).vector)
//			let renderList = continentRenderLists[bufferIndex]
//		frameSelectSemaphore.signal()
//
//		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
//		for primitive in renderList {
//			render(primitive: primitive, into: encoder)
//		}
		
		encoder.popDebugGroup()
	}
	
	func renderCountryBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render country borders")
		defer {
			encoder.popDebugGroup()
		}
		
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection,
																	 widthInner: Stylesheet.shared.countryBorderWidthInner.value * borderScale,
																	 widthOuter: Stylesheet.shared.countryBorderWidthOuter.value * borderScale,
																	 color: Stylesheet.shared.countryBorderColor.float4)
			let instances = countryInstanceUniforms[bufferIndex]
			let count = countryFrameLineSegmentCount[bufferIndex]
		frameSelectSemaphore.signal()
		
		if count == 0 {
			return
		}
		
		encoder.setRenderPipelineState(pipeline)
		
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		encoder.setVertexBuffer(instances, offset: 0, index: 2)
		
		renderInstanced(primitive: lineSegmentPrimitive, count: count, into: encoder)
	}
	
	func renderProvinceBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render province borders")
		encoder.setRenderPipelineState(pipeline)
		
//		frameSelectSemaphore.wait()
//			var uniforms = FrameUniforms(mvpMatrix: projection,
//																	 widthInner: Stylesheet.shared.provinceBorderWidthInner.value * borderScale,
//																	 widthOuter: Stylesheet.shared.provinceBorderWidthOuter.value * borderScale,
//																	 color: Stylesheet.shared.provinceBorderColor.float4)
//			let renderList = provinceRenderLists[bufferIndex]
//		frameSelectSemaphore.signal()
//
//		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
//		for primitive in renderList {
//			render(primitive: primitive, into: encoder)
//		}
		
		encoder.popDebugGroup()
	}
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> LoddedBorderHash {
		return "\(regionHash)-\(lod)".hashValue
	}
}

func makeLineSegmentPrimitive(in device: MTLDevice) -> RenderPrimitive {
	let vertices: [Vertex] = [
		Vertex(0.0, -0.5),
		Vertex(1.0, -0.5),
		Vertex(1.0,  0.5),
		Vertex(0.0,  0.5)
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
		for v in contour.vertices {
			vertices.append(InstanceUniforms(vertex: simd_float2(x: v.x, y: v.y)))
		}
	}
	return vertices
}
