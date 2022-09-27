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
		guard let newBuffer = device.makeBuffer(bytes: vertices, length: bufLen, options: .storageModeShared) else {
			fatalError("Could not create vertex buffer for \(debugName)")
		}
		
		self.vertexBuffer = newBuffer
		self.vertexBuffer.label = "Debug - \(debugName) vertex buffer"
	}
}

func render(primitive: DebugRenderPrimitive, into encoder: MTLRenderCommandEncoder) {
	encoder.setVertexBuffer(primitive.vertexBuffer, offset: 0, index: 0)
	encoder.drawPrimitives(type: primitive.drawMode, vertexStart: 0, vertexCount: primitive.elementCount)
}


protocol DebugMarker {
	var renderPrimitive: DebugRenderPrimitive { get }
}

// DebugRenderer borrows Map shader, so this must match RegionRenderer's FrameUniforms
fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
}

// DebugRenderer borrows Map shader, so this must match RegionRenderer's InstanceUniforms
fileprivate struct InstanceUniforms {
	let color: simd_float4
}

class DebugRenderer {
	typealias DebugPrimitive = DebugRenderPrimitive
	typealias RenderList = ContiguousArray<DebugPrimitive>
	static private var _shared: DebugRenderer!
	static var shared: DebugRenderer {
		return _shared
	}
	static let kMaxDebugMarkers = 500
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]

	var primitives: [UUID: DebugRenderPrimitive]
	var transientPrimitives: [DebugRenderPrimitive]
	var mainCursorHandle: UUID?
	var mainSelectionHandle: UUID?
	var renderLists: [RenderList] = []
	var frameSwitchSemaphore = DispatchSemaphore(value: 1)
	
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
	
	func addCrossbox(for box: Aabb, alpha: Float, name: String, color: UIColor = .magenta) -> UUID {
		let handle = UUID()
		let newBox = makeDebugCrossbox(for: box, color: color, name: name)
		primitives[handle] = newBox
		return handle
	}
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int) {
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
			self.renderLists = Array(repeating: RenderList(), count: bufferCount)
			self.instanceUniforms = (0..<bufferCount).map { _ in
				return device.makeBuffer(length: DebugRenderer.kMaxDebugMarkers * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		primitives = [:]
		transientPrimitives = []
		
		DebugRenderer._shared = self
	}
	
	func prepareFrame(bufferIndex: Int) {
		let frameRenderList = RenderList(primitives.values + transientPrimitives)
		
		var markerColors = Array<InstanceUniforms>()
		markerColors.reserveCapacity(frameRenderList.count)
		for marker in frameRenderList {
			let u = InstanceUniforms(color: marker.color.vector)
			markerColors.append(u)
		}
		
		frameSwitchSemaphore.wait()
			self.renderLists[bufferIndex] = frameRenderList
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: markerColors, byteCount: MemoryLayout<InstanceUniforms>.stride * markerColors.count)
			transientPrimitives.removeAll()
		frameSwitchSemaphore.signal()
	}
	
	func renderMarkers(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render debug layer")
		encoder.setRenderPipelineState(pipeline)
		
		frameSwitchSemaphore.wait()
			let renderList = self.renderLists[bufferIndex]
			var frameUniforms = FrameUniforms(mvpMatrix: projection)
			let uniforms = self.instanceUniforms[bufferIndex]
		frameSwitchSemaphore.signal()
		
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
	
	func makeDebugCrossbox(for box: Aabb, color: UIColor, name: String) -> DebugRenderPrimitive {
		let vertices: [Vertex] = [
			Vertex(box.minX, box.minY),
			Vertex(box.maxX, box.minY),
			Vertex(box.maxX, box.maxY),
			Vertex(box.minX, box.maxY),
			Vertex(box.minX, box.minY),	// Close the quad
			Vertex(box.maxX, box.maxY), // Cross the quad
			Vertex(box.maxX, box.minY),
			Vertex(box.minX, box.maxY)
		]
		return DebugRenderPrimitive(mode: .lineStrip,
																vertices: vertices,
																device: device,
																color: color.tuple(),
																debugName: name)
	}
}
