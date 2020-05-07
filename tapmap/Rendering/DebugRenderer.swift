//
//  DebugRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd
import CoreGraphics
import UIKit.UIColor

class DebugRenderPrimitive {
	let drawMode: MTLPrimitiveType
	let vertexBuffer: MTLBuffer
	let elementCount: Int
	
	let color: Color
	let name: String
	
	init(mode: MTLPrimitiveType, vertices: [Vertex], device: MTLDevice, color c: Color, debugName: String) {
		drawMode = mode
		color = c
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
		self.vertexBuffer.label = "Debug - \(debugName) vertex buffer"
		self.vertexBuffer.contents().copyMemory(from: vertices, byteCount: bufLen)
	}
}

func render(primitive: DebugRenderPrimitive, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	encoder.drawPrimitives(type: primitive.drawMode, vertexStart: 0, vertexCount: primitive.elementCount)
}


protocol DebugMarker {
	var renderPrimitive: DebugRenderPrimitive { get }
}

struct DebugUniforms {
	let mvpMatrix: simd_float4x4
	var color: simd_float4
}

class DebugRenderer {
	static private var _shared: DebugRenderer!
	static var shared: DebugRenderer {
		return _shared
	}

	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	var primitives: [UUID: DebugRenderPrimitive]
	var transientPrimitives: [DebugRenderPrimitive]
	
	var mainCursorHandle: UUID?
	var mainSelectionHandle: UUID?
	
	func moveCursor(_ x: CGFloat, _ y: CGFloat) {
		if mainCursorHandle == nil {
			mainCursorHandle = UUID()
		}
		
		let newCursor = makeDebugCursor(at: Vertex(Vertex.Precision(x), Vertex.Precision(y)), name: "Debug - cursor")
		primitives[mainCursorHandle!] = newCursor
	}
	
	func moveSelection(_ box: Aabb) {
		if mainSelectionHandle == nil {
			mainSelectionHandle = UUID()
		}
		
		let newSelection = makeDebugQuad(for: box, color: .green, name: "Debug - selection")
		primitives[mainSelectionHandle!] = newSelection
	}
	
	func addQuad(for box: Aabb, alpha: Float, name: String, color: UIColor = .magenta) -> UUID {
		let handle = UUID()
		let newQuad = makeDebugQuad(for: box, color: color, name: name)
		primitives[handle] = newQuad
		return handle
	}
	
	func removeQuad(handle: UUID) {
		primitives.removeValue(forKey: handle)
	}
	
	func addTransientQuad(for box: Aabb, alpha: Float, name: String, color: UIColor = .magenta) {
		let colorWithAlpha = color.withAlphaComponent(CGFloat(alpha))
		let newQuad = makeDebugQuad(for: box, color: colorWithAlpha, name: name)
		transientPrimitives.append(newQuad)
	}
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "mapVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "mapFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		primitives = [:]
		transientPrimitives = []
		
		DebugRenderer._shared = self
	}
	
	func renderMarkers(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder) {
		encoder.pushDebugGroup("Render debug layer")
		encoder.setRenderPipelineState(pipeline)
		
		var uniforms = DebugUniforms(mvpMatrix: projection,
																 color: simd_float4())
		
		
		// Permanent markers
		for primitive in primitives.values {
			uniforms.color = primitive.color.vector
			render(primitive: primitive, into: encoder)
		}
		
		// One-frame markers
		for primitive in transientPrimitives {
			uniforms.color = primitive.color.vector
			render(primitive: primitive, into: encoder)
		}
		transientPrimitives.removeAll()
	}
	
	func makeDebugCursor(at p: Vertex, name: String) -> DebugRenderPrimitive {
		let vertices: [Vertex] = [
			Vertex(p.x, p.y),
			Vertex(p.x - 3.0, p.y + 5.0),
			Vertex(p.x + 3.0, p.y + 5.0)
		]
		return DebugRenderPrimitive(mode: .triangle,
																vertices: vertices,
																device: device,
																color: Color(r: 1.0, g: 0.0, b: 1.0, a: 0.5),
																debugName: name)
	}

	func makeDebugQuad(for box: Aabb, color: UIColor, name: String) -> DebugRenderPrimitive {
		let vertices: [Vertex] = [
			Vertex(box.minX, box.minY),
			Vertex(box.maxX, box.minY),
			Vertex(box.maxX, box.maxY),
			Vertex(box.minX, box.maxY),
			Vertex(box.minX, box.minY)	// Close the quad
		]
		return DebugRenderPrimitive(mode: .lineStrip,
																vertices: vertices,
																device: device,
																color: color.tuple(),
																debugName: name)
	}
}
