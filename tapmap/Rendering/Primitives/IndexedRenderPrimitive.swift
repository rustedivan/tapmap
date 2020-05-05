//
//  IndexedRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal

class IndexedRenderPrimitive<VertexType> {
	let ownerHash: Int
	
	let vertexBuffer: MTLBuffer
	let elementCount: Int
	let indexBuffer: MTLBuffer
	
	let color: (r: Float, g: Float, b: Float, a: Float)
	let name: String
	
	// Indexed draw mode
	init(vertices: [VertexType],
			 device: MTLDevice,
			 indices: [UInt32],
			 color c: (r: Float, g: Float, b: Float, a: Float),
			 ownerHash hash: Int, debugName: String) {
		color = c
		
		ownerHash = hash
		name = debugName
		
		guard !indices.isEmpty else {
			fatalError("Do not create render primitive for empty meshes")
		}
		
		let vertexBufLen = MemoryLayout<VertexType>.stride * vertices.count
		let indexBufLen = MemoryLayout<UInt32>.stride * indices.count
		
		guard let newVertBuffer = device.makeBuffer(length: vertexBufLen, options: .storageModeShared),
					let	newIndexBuffer = device.makeBuffer(length: indexBufLen, options: .storageModeShared) else {
				fatalError("Could not create buffers for \(debugName)")
		}
		
		self.vertexBuffer = newVertBuffer
		self.vertexBuffer.label = "\(debugName) vertex buffer"
		self.vertexBuffer.contents().copyMemory(from: vertices, byteCount: vertexBufLen)
		
		self.indexBuffer = newIndexBuffer
		self.indexBuffer.label = "\(debugName) index buffer"
		self.indexBuffer.contents().copyMemory(from: indices, byteCount: indexBufLen)
		
		elementCount = indices.count
	}
}

func render<T>(primitive: IndexedRenderPrimitive<T>, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	encoder.drawIndexedPrimitives(type: .triangle,
																indexCount: primitive.elementCount,
																indexType: .uint32,
																indexBuffer: primitive.indexBuffer,
																indexBufferOffset: 0)
}
