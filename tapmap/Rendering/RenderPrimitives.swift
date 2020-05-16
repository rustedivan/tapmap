//
//  RenderPrimitives.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal

class BaseRenderPrimitive<VertexType> {
	let ownerHash: Int
	
	let drawMode: MTLPrimitiveType
	let vertexBuffer: MTLBuffer
	let elementCounts: [Int]
	let indexBuffer: MTLBuffer
	
	let color: Color
	let name: String
	
	init(polygons: [[VertexType]],
			 indices: [[UInt16]],
			 drawMode mode: MTLPrimitiveType,
			 device: MTLDevice,
			 color c: Color,
			 ownerHash hash: Int, debugName: String) {
		color = c
		
		ownerHash = hash
		name = debugName
		drawMode = mode
		
		guard !indices.isEmpty else {
			fatalError("Do not create render primitive for empty meshes")
		}
		
		// Concatenate all vertex rings into one buffer
		var allVertices: [VertexType] = []
		var allIndices: [UInt32] = []
		var polyRanges: [Int] = []
		for (p, i) in zip(polygons, indices) {
			guard !p.isEmpty else { continue }
			allVertices.append(contentsOf: p)
			allIndices.append(contentsOf: i.map { UInt32($0) })
			polyRanges.append(i.count)
		}
		elementCounts = polyRanges
		
		let vertexBufLen = MemoryLayout<VertexType>.stride * allVertices.count
		let indexBufLen = MemoryLayout<UInt32>.stride * allIndices.count
		
		guard let newVertBuffer = device.makeBuffer(bytes: allVertices, length: vertexBufLen, options: .storageModeShared),
					let	newIndexBuffer = device.makeBuffer(bytes: allIndices, length: indexBufLen, options: .storageModeShared) else {
				fatalError("Could not create buffers for \(debugName)")
		}
		
		self.vertexBuffer = newVertBuffer
		self.vertexBuffer.label = "\(debugName) vertex buffer"
		
		self.indexBuffer = newIndexBuffer
		self.indexBuffer.label = "\(debugName) index buffer"
	}
}

typealias RenderPrimitive = BaseRenderPrimitive<Vertex>
typealias FixedScaleRenderPrimitive = BaseRenderPrimitive<ScaleVertex>

func render<T>(primitive: BaseRenderPrimitive<T>, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	
	var cursor = 0
	for range in primitive.elementCounts {
		encoder.drawIndexedPrimitives(type: primitive.drawMode,
																	indexCount: range,
																	indexType: .uint32,
																	indexBuffer: primitive.indexBuffer,
																	indexBufferOffset: cursor)
		cursor += range * MemoryLayout<UInt32>.stride
	}
}
