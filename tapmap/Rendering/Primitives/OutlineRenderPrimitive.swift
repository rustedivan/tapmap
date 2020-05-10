//
//  OutlineRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal

class OutlineRenderPrimitive {
	let ownerHash: Int
	
	var vertexBuffer: MTLBuffer
	let elementCounts: [Int]
	
	let name: String
	
	init(contours: RegionContours, device: MTLDevice, ownerHash hash: Int, debugName: String) {
		ownerHash = hash
		name = debugName
		
		guard !contours.isEmpty else {
			fatalError("Do not create render primitive for empty contours")
		}
		
		// Concatenate all vertex rings into one buffer
		var vertices: [ScaleVertex] = []
		var ringLengths: [Int] = []
		for ring in contours {
			guard !ring.isEmpty else { continue }
			vertices.append(contentsOf: ring)
			ringLengths.append(ring.count)
		}
		
		elementCounts = ringLengths
		let bufLen = MemoryLayout<ScaleVertex>.stride * vertices.count
		guard let newBuffer = device.makeBuffer(bytes: vertices, length: bufLen, options: .storageModeShared) else {
			fatalError("Could not create vertex buffer for \(debugName)")
		}
		
		self.vertexBuffer = newBuffer
		self.vertexBuffer.label = "\(debugName) vertex buffer"
	}
}


func render(primitive: OutlineRenderPrimitive, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	
	var cursor = 0
	for range in primitive.elementCounts {
		encoder.drawPrimitives(type: .triangleStrip, vertexStart: cursor, vertexCount: range)
		cursor += range
	}
}

