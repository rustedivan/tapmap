//
//  BorderRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-04-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd

struct BorderUniforms {
	let mvpMatrix: simd_float4x4
	let width: simd_float1
	var color: simd_float4
}

class BorderRenderer {
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	
	var borderPrimitives: [Int : OutlineRenderPrimitive]
	var borderWidth: Float
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	let borderQueue: DispatchQueue
	var pendingBorders: Set<Int> = []

	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		borderWidth = 0.0
		
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "borderVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "borderFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
				
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		borderPrimitives = [:]
		
		borderQueue = DispatchQueue(label: "Border construction", qos: .userInitiated, attributes: .concurrent)
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
	}
	
	func updateStyle(zoomLevel: Float) {
		borderWidth = 0.4 / zoomLevel
	}
	
	func prepareGeometry(visibleContinents: GeoContinentMap, visibleCountries: GeoCountryMap) {
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
				
				if let tessellation = streamer.tessellation(for: borderHash, atLod: lodLevel, streamIfMissing: true) {
					pendingBorders.insert(loddedBorderHash)
					borderQueue.async {
						let innerWidth: Float
						let outerWidth: Float
						
						let countourVertices: [[Vertex]]
						if visibleContinents[borderHash] != nil {
							innerWidth = 0.1
							outerWidth = 1.0
							countourVertices = [(tessellation.contours.first?.vertices ?? [])]
						} else {
							innerWidth = 0.5
							outerWidth = 0.1
							countourVertices = tessellation.contours.map({$0.vertices})
						}
						
						let borderOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: innerWidth, outerExtent: outerWidth) }
						let outlineGeometry: RegionContours = countourVertices.map(borderOutline)

						// Create the render primitive and update book-keeping on the main thread
						// $ Can replace this return to main with a semaphor/mutex
						DispatchQueue.main.async {
							let outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																														device: self.device,
																														ownerHash: 0,
																														debugName: "Border \(borderHash)@\(lodLevel)")
							self.borderPrimitives[loddedBorderHash] = outlinePrimitive
							self.pendingBorders.remove(loddedBorderHash)
						}
					}
				}
			}
		}
		
		if !borderLodMiss && actualBorderLod != streamer.wantedLodLevel {
			actualBorderLod = streamer.wantedLodLevel
		}
	}
	
	func renderContinentBorders(_ continents: Set<Int>, inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render continent borders")
		encoder.setRenderPipelineState(pipeline)
		
		let continentOutlineLod = max(actualBorderLod, 0)	// $ Turn up the limit once border width is under control (set min/max outline width and ramp between )
		let loddedBorderKeys = continents.map { borderHashLodKey($0, atLod: continentOutlineLod) }
		
		var uniforms = BorderUniforms(mvpMatrix: projection, width: borderWidth * 2.0, color: simd_float4(arrayLiteral: 1.0, 0.5, 0.7, 1.0))
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		
		for key in loddedBorderKeys {
			guard let primitive = borderPrimitives[key] else { continue }
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func renderCountryBorders(_ countries: Set<Int>, inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render country borders")
		encoder.setRenderPipelineState(pipeline)
		
		var uniforms = BorderUniforms(mvpMatrix: projection, width: borderWidth, color: simd_float4(arrayLiteral: 1.0, 1.0, 1.0, 1.0))
		encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
		
		let loddedBorderKeys = countries.map { borderHashLodKey($0, atLod: actualBorderLod) }
		for key in loddedBorderKeys {
			guard let primitive = borderPrimitives[key] else { continue }
			render(primitive: primitive, into: encoder)
		}
		
		encoder.popDebugGroup()
	}
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> Int {
		return "\(regionHash)-\(lod)".hashValue
	}
}
