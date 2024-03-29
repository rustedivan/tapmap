//
//  RegionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
}

fileprivate struct InstanceUniforms {
	var color: simd_float4
}

class RegionRenderer {
	typealias RegionPrimitive = RenderPrimitive
	typealias RenderList = ContiguousArray<RegionPrimitive>

	static let kMaxVisibleRegions = 5000
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]
	var renderLists: [RenderList] = []
	var frameSelectSemaphore = DispatchSemaphore(value: 1)
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.sampleCount = 4
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "mapVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "mapFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		pipelineDescriptor.vertexBuffers[1].mutability = .immutable
		pipelineDescriptor.vertexBuffers[2].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.renderLists = Array(repeating: RenderList(), count: bufferCount)
			self.instanceUniforms = (0..<bufferCount).map { _ in
				return device.makeBuffer(length: RegionRenderer.kMaxVisibleRegions * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}
	
	func prepareFrame(visibleContinentSet: Dictionary<RegionHash, GeoContinent>.Keys,
										visibleCountrySet: Dictionary<RegionHash, GeoCountry>.Keys,
										visibleProvinceSet: Dictionary<RegionHash, GeoProvince>.Keys,
										visitedSet: Set<RegionHash>,
										regionContinentMap: GeoContinentMap,
										bufferIndex: Int) {
		let frameContinentRenderList = RenderList(visibleContinentSet.compactMap { regionHash in
																		return GeometryStreamer.shared.renderPrimitive(for: regionHash, streamIfMissing: true)
																	 })
		let frameCountryRenderList = 	 RenderList(visibleCountrySet.compactMap { regionHash in
																		return GeometryStreamer.shared.renderPrimitive(for: regionHash, streamIfMissing: true)
																	 })
		let frameProvinceRenderList =  RenderList(visibleProvinceSet.compactMap { regionHash in
																		return GeometryStreamer.shared.renderPrimitive(for: regionHash, streamIfMissing: true)
																	 })
		
		let stylesheet = Stylesheet.shared
		var styles = Array<InstanceUniforms>()
		styles.reserveCapacity(frameContinentRenderList.count +
													 frameCountryRenderList.count +
													 frameProvinceRenderList.count)
		
		// Style continents
		for continent in frameContinentRenderList {
			let u = InstanceUniforms(color: stylesheet.continentColor(for: continent.ownerHash, in: regionContinentMap))
			styles.append(u)
		}
		
		// Style countries
		for country in frameCountryRenderList {
			let u = InstanceUniforms(color: stylesheet.countryColor(for: country.ownerHash, in: regionContinentMap))
			styles.append(u)
		}
		
		// Style provinces
		for province in frameProvinceRenderList {
			let visited = visitedSet.contains(province.ownerHash)
			
			// Visited provinces render in authored color, unvisited in tinted country color
			let c = visited ? province.color.vector
											: stylesheet.provinceColor(for: province.ownerHash, in: regionContinentMap)
			let u = InstanceUniforms(color: c)
			styles.append(u)
		}
		
		frameSelectSemaphore.wait()
			self.renderLists[bufferIndex] = (frameContinentRenderList + frameCountryRenderList + frameProvinceRenderList)
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: styles, byteCount: MemoryLayout<InstanceUniforms>.stride * styles.count)
		frameSelectSemaphore.signal()
	}
	
	func renderWorld(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render world")
		encoder.setRenderPipelineState(pipeline)
		
		frameSelectSemaphore.wait()
			var frameUniforms = FrameUniforms(mvpMatrix: projection)
			let renderList = self.renderLists[bufferIndex]
			let uniforms = self.instanceUniforms[bufferIndex]
		frameSelectSemaphore.signal()
		
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setVertexBuffer(uniforms, offset: 0, index: 2)
		
		var instanceCursor = 0
		for primitive in renderList {
			encoder.setVertexBufferOffset(instanceCursor, index: 2)
			render(primitive: primitive, into: encoder)
			
			instanceCursor += MemoryLayout<InstanceUniforms>.stride
		}
		
		encoder.popDebugGroup()
	}
}
