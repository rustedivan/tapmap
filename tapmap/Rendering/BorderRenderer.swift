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

class BorderRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var borderPrimitives: [Int : OutlineRenderPrimitive]
	var continentRenderList: [OutlineRenderPrimitive] = []
	var countryRenderList: [OutlineRenderPrimitive] = []
	var borderWidth: Float
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	let borderQueue: DispatchQueue
	let publishQueue: DispatchQueue
	var pendingBorders: Set<Int> = []
	var generatedBorders: [(Int, OutlineRenderPrimitive)] = []	// Border primitives that were generated this frame

	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		borderWidth = 0.0
		
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "borderVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "borderFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
				
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		borderPrimitives = [:]
		
		borderQueue = DispatchQueue(label: "Border construction", qos: .userInitiated, attributes: .concurrent)
		publishQueue = DispatchQueue(label: "Border delivery")
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
	}
	
	func updateStyle(zoomLevel: Float) {
		borderWidth = 1.0 / zoomLevel
	}
	
	func prepareFrame(visibleContinents: GeoContinentMap, visibleCountries: GeoCountryMap) {
		let streamer = GeometryStreamer.shared
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		let updateSet: [Int] = Array(visibleContinents.keys) + Array(visibleCountries.keys)
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
					let innerWidth: Float
					let outerWidth: Float
					
					let countourVertices: [[Vertex]]
					if visibleContinents[borderHash] != nil {
						innerWidth = 0.1
						outerWidth = 0.5
						countourVertices = [(tessellation.contours.first?.vertices ?? [])]
					} else {
						innerWidth = 0.3
						outerWidth = 0.1
						countourVertices = tessellation.contours.map({$0.vertices})
					}
					
					let borderOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: innerWidth, outerExtent: outerWidth) }
					let outlineGeometry: RegionContours = countourVertices.map(borderOutline)
					let outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																												device: self.device,
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
		continentRenderList = visibleContinents.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: continentOutlineLod)
			return borderPrimitives[loddedKey]
		}
		
		countryRenderList = visibleCountries.compactMap {
			let loddedKey = borderHashLodKey($0.key, atLod: actualBorderLod)
			return borderPrimitives[loddedKey]
		}
	}
	
	func renderContinentBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render continent borders")
		encoder.setRenderPipelineState(pipeline)
		
		var uniforms = FrameUniforms(mvpMatrix: projection, width: borderWidth * 2.0, color: Color(r: 1.0, g: 0.5, b: 0.7, a: 1.0).vector)
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		
		for primitive in continentRenderList {
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func renderCountryBorders(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render country borders")
		encoder.setRenderPipelineState(pipeline)
		
		var uniforms = FrameUniforms(mvpMatrix: projection, width: borderWidth, color: Color(r: 1.0, g: 1.0, b: 1.0, a: 1.0).vector)
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		
		for primitive in countryRenderList {
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> Int {
		return "\(regionHash)-\(lod)".hashValue
	}
}
