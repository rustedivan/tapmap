//
//  ArrayedRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal

class ArrayedRenderPrimitive {
	let ownerHash: Int
	
	let vertexBuffer: MTLBuffer
	let elementCount: Int
	
	let color: Color
	let name: String
	
	init(vertices: [Vertex], device: MTLDevice, color c: Color, ownerHash hash: Int, debugName: String) {
		color = c

		ownerHash = hash
		name = debugName
		elementCount = vertices.count
		
		guard !vertices.isEmpty else {
			fatalError("Do not create render primitive for empty meshes")
		}
		
		let bufLen = MemoryLayout<Vertex>.stride * elementCount
		guard let newBuffer = device.makeBuffer(length: bufLen, options: .storageModeShared) else {
			fatalError("Could not create vertex buffer for \(debugName)")
		}
		
		self.vertexBuffer = newBuffer
		self.vertexBuffer.label = "\(debugName) vertex buffer"
		self.vertexBuffer.contents().copyMemory(from: vertices, byteCount: bufLen)
	}
}

func render(primitive: ArrayedRenderPrimitive, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: primitive.elementCount)
}
