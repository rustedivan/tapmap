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
	
	let color: Color
	let name: String
	
	// Indexed draw mode
	init(vertices: [VertexType],
			 indices: [UInt16],
			 device: MTLDevice,
			 color c: Color,
			 ownerHash hash: Int, debugName: String) {
		color = c
		
		ownerHash = hash
		name = debugName
		
		guard !indices.isEmpty else {
			fatalError("Do not create render primitive for empty meshes")
		}
		
		let vertexBufLen = MemoryLayout<VertexType>.stride * vertices.count
		let indexBufLen = MemoryLayout<UInt16>.stride * indices.count
		
		guard let newVertBuffer = device.makeBuffer(bytes: vertices, length: vertexBufLen, options: .storageModeShared),
					let	newIndexBuffer = device.makeBuffer(bytes: indices, length: indexBufLen, options: .storageModeShared) else {
				fatalError("Could not create buffers for \(debugName)")
		}
		
		self.vertexBuffer = newVertBuffer
		self.vertexBuffer.label = "\(debugName) vertex buffer"
		
		self.indexBuffer = newIndexBuffer
		self.indexBuffer.label = "\(debugName) index buffer"
		
		elementCount = indices.count
	}
}

func render<T>(primitive: IndexedRenderPrimitive<T>, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	encoder.drawIndexedPrimitives(type: .triangle,
																indexCount: primitive.elementCount,
																indexType: .uint16,
																indexBuffer: primitive.indexBuffer,
																indexBufferOffset: 0)
}
