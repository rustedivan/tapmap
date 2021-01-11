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

class BorderRenderer {
	typealias BorderPrimitive = FixedScaleRenderPrimitive
	typealias RenderList = ContiguousArray<BorderPrimitive>
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var borderPrimitives: [Int : BorderPrimitive]
	var continentRenderLists: [RenderList] = []
	var countryRenderLists: [RenderList] = []
	var provinceRenderLists: [RenderList] = []
	var frameSelectSemaphore = DispatchSemaphore(value: 1)

	var borderScale: Float
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	let borderQueue: DispatchQueue
	let publishQueue: DispatchQueue
	var pendingBorders: Set<Int> = []
	var generatedBorders: [(Int, BorderPrimitive)] = []	// Border primitives that were generated this frame

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
			self.continentRenderLists = Array(repeating: RenderList(), count: bufferCount)
			self.countryRenderLists = Array(repeating: RenderList(), count: bufferCount)
			self.provinceRenderLists = Array(repeating: RenderList(), count: bufferCount)
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		borderPrimitives = [:]
		
		borderQueue = DispatchQueue(label: "Border construction", qos: .userInitiated, attributes: .concurrent)
		publishQueue = DispatchQueue(label: "Border delivery")
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
	}
	
	func prepareFrame(borderedContinents: GeoContinentMap, borderedCountries: GeoCountryMap, borderedProvinces: GeoProvinceMap, zoom: Float, bufferIndex: Int) {
		let streamer = GeometryStreamer.shared
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		let updateSet: [Int] = Array(borderedContinents.keys) + Array(borderedCountries.keys) + Array(borderedProvinces.keys)
		for borderHash in updateSet {
			let loddedBorderHash = borderHashLodKey(borderHash, atLod: lodLevel)
			if borderPrimitives[loddedBorderHash] == nil {
				borderLodMiss = true
				if pendingBorders.contains(loddedBorderHash) {
					continue
				}
				
				guard let tessellation = streamer.tessellation(for: borderHash, atLod: lodLevel, streamIfMissing: true) else {
					return
				}
				
				// Create the render primitive and update book-keeping on the main thread
				pendingBorders.insert(loddedBorderHash)
				borderQueue.async {
					let countourVertices: [[Vertex]]
					if borderedContinents[borderHash] != nil {
						countourVertices = [(tessellation.contours.first?.vertices ?? [])]
					} else {
						countourVertices = tessellation.contours.map({$0.vertices})
					}
					
					let borderOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: 1.0, outerExtent: 1.0) }
					let outlineGeometry: RegionContours = countourVertices.map(borderOutline)
					
					var cursor = 0
					var stackedIndices: [[UInt16]] = []
					for outline in outlineGeometry {
						let indices = 0..<UInt16(outline.count)
						let stackedRing = indices.map { $0 + UInt16(cursor) }
						stackedIndices.append(stackedRing)
						cursor += outline.count
					}
					
					let outlinePrimitive = BorderPrimitive(polygons: outlineGeometry,
																								 indices: stackedIndices,
																								 drawMode: .triangleStrip,
																								 device: self.device,
																								 color: Color(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
																								 ownerHash: 0,
																								 debugName: "Border \(borderHash)@\(lodLevel)")
					
					// Don't allow reads while publishing finished primitive
					self.publishQueue.async(flags: .barrier) {
						self.generatedBorders.append((loddedBorderHash, outlinePrimitive))
					}
				}
			}
		}
		
		// Publish newly generated borders to the renderer
		publishQueue.sync {
			for (key, primitive) in generatedBorders {
				self.borderPrimitives[key] = primitive
				self.pendingBorders.remove(key)
			}
			let finishedBorders = generatedBorders.map { $0.0 }
			pendingBorders = pendingBorders.subtracting(finishedBorders)
			generatedBorders = []
		}
		
		if !borderLodMiss && actualBorderLod != streamer.wantedLodLevel {
			actualBorderLod = streamer.wantedLodLevel
		}
		
		let continentOutlineLod = max(actualBorderLod, 0)	// $ Turn up the limit once border width is under control (set min/max outline width and ramp between )
		let frameContinentRenderList = RenderList(borderedContinents.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: continentOutlineLod)
			return borderPrimitives[loddedKey]
		})
		
		let frameCountryRenderList = RenderList(borderedCountries.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderPrimitives[loddedKey]
		})
		
		let frameProvinceRenderList = RenderList(borderedProvinces.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderPrimitives[loddedKey]
		})
		
		frameSelectSemaphore.wait()
			self.borderScale = 1.0 / zoom
			self.continentRenderLists[bufferIndex] = frameContinentRenderList
			self.countryRenderLists[bufferIndex] = frameCountryRenderList
			self.provinceRenderLists[bufferIndex] = frameProvinceRenderList
		frameSelectSemaphore.signal()
	}
	
	func renderContinentBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render continent borders")
		encoder.setRenderPipelineState(pipeline)
		
		frameSelectSemaphore.wait()
			var frameUniforms = FrameUniforms(mvpMatrix: projection,
																				widthInner: Stylesheet.shared.continentBorderWidthInner.value * borderScale,
																				widthOuter: Stylesheet.shared.continentBorderWidthOuter.value * borderScale,
																				color: Color(r: 1.0, g: 0.5, b: 0.7, a: 1.0).vector)
			let renderList = continentRenderLists[bufferIndex]
		frameSelectSemaphore.signal()
		
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		for primitive in renderList {
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func renderCountryBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render country borders")
		encoder.setRenderPipelineState(pipeline)
		
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection,
																	 widthInner: Stylesheet.shared.countryBorderWidthInner.value * borderScale,
																	 widthOuter: Stylesheet.shared.countryBorderWidthOuter.value * borderScale,
																	 color: Stylesheet.shared.countryBorderColor.float4)
			let renderList = countryRenderLists[bufferIndex]
		frameSelectSemaphore.signal()
		
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		for primitive in renderList {
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func renderProvinceBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render province borders")
		encoder.setRenderPipelineState(pipeline)
		
		frameSelectSemaphore.wait()
			var uniforms = FrameUniforms(mvpMatrix: projection,
																	 widthInner: Stylesheet.shared.provinceBorderWidthInner.value * borderScale,
																	 widthOuter: Stylesheet.shared.provinceBorderWidthOuter.value * borderScale,
																	 color: Stylesheet.shared.provinceBorderColor.float4)
			let renderList = provinceRenderLists[bufferIndex]
		frameSelectSemaphore.signal()
		
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		for primitive in renderList {
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> Int {
		return "\(regionHash)-\(lod)".hashValue
	}
}
