//
//  DebugRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

class DebugRenderPrimitive {
	let drawMode: GLenum
	var vertexBuffer: GLuint = 0
	let elementCount: GLsizei
	
	let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
	let name: String
	
	init(mode: GLenum, vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), debugName: String) {
		drawMode = mode
		color = c
		name = debugName
		
		guard !vertices.isEmpty else {
			elementCount = 0
			return
		}
		
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		glBufferData(GLenum(GL_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<Vertex>.stride * vertices.count),
								 vertices,
								 GLenum(GL_STATIC_DRAW))
		
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
		elementCount = GLsizei(vertices.count)
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), vertexBuffer, 0, "Debug - \(debugName).vertices")
	}
	
	deinit {
		glDeleteBuffers(1, &vertexBuffer)
	}
}

func render(primitive: DebugRenderPrimitive) {
	guard primitive.elementCount > 0 else {
		return
	}
	
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	glVertexAttribPointer(VertexAttribs.position.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<Vertex>.stride), BUFFER_OFFSET(0))
	
	glDrawArrays(primitive.drawMode,
							 0,
							 primitive.elementCount)
}


protocol DebugMarker {
	var renderPrimitive: DebugRenderPrimitive { get }
}

func makeDebugCursor(at p: Vertex, name: String) -> DebugRenderPrimitive {
	let vertices: [Vertex] = [
		Vertex(p.x, p.y),
		Vertex(p.x - 3.0, p.y + 5.0),
		Vertex(p.x + 3.0, p.y + 5.0)
	]
	return DebugRenderPrimitive(mode: GLenum(GL_TRIANGLES),
															vertices: vertices,
															color: (r: 1.0, g: 0.0, b: 1.0, a: 0.5),
															debugName: name)
}

func makeDebugQuad(for box: Aabb, alpha: Float, name: String) -> DebugRenderPrimitive {
	let vertices: [Vertex] = [
		Vertex(box.minX, box.minY),
		Vertex(box.maxX, box.minY),
		Vertex(box.maxX, box.maxY),
		Vertex(box.minX, box.maxY),
	]
	return DebugRenderPrimitive(mode: GLenum(GL_LINE_LOOP),
															vertices: vertices,
															color: (r: 0.0, g: 1.0, b: 1.0, a: alpha),
															debugName: name)
}

class DebugRenderer {
	static private var _shared: DebugRenderer!
	static var shared: DebugRenderer {
		get {
			if _shared == nil {
				_shared = DebugRenderer()
			}
			return _shared
		}
	}
	let debugProgram: GLuint
	let markerUniforms : (modelViewMatrix: GLint, color: GLint)
	var primitives: [UUID: DebugRenderPrimitive]
	
	func addCursor(_ p: Vertex, name: String) -> UUID {
		let handle = UUID()
		let newCursor = makeDebugCursor(at: p, name: name)
		primitives[handle] = newCursor
		return handle
	}
	
	func moveCursor(_ p: Vertex, handle: UUID) {
		let cursor = primitives[handle]!
		let newCursor = makeDebugCursor(at: p, name: cursor.name)
		primitives[handle] = newCursor
	}
	
	func addQuad(for box: Aabb, alpha: Float, name: String) -> UUID {
		let handle = UUID()
		let newQuad = makeDebugQuad(for: box, alpha: alpha, name: name)
		primitives[handle] = newQuad
		return handle
	}
	
	func removeQuad(handle: UUID) {
		primitives.removeValue(forKey: handle)
	}
	
	init?() {
		debugProgram = loadShaders(shaderName: "DebugShader")
		guard debugProgram != 0 else {
			print("Failed to load debug shaders")
			return nil
		}
		
		markerUniforms.modelViewMatrix = glGetUniformLocation(debugProgram, "modelViewProjectionMatrix")
		markerUniforms.color = glGetUniformLocation(debugProgram, "markerColor")
		primitives = [:]
	}
	
	func renderMarkers(inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render opening effect")
		glUseProgram(debugProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(markerUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		glEnable(GLenum(GL_BLEND))
		glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
		
		for primitive in primitives.values {
			// Set color
			glUniform4f(markerUniforms.color,
									GLfloat(primitive.color.r),
									GLfloat(primitive.color.g),
									GLfloat(primitive.color.b),
									GLfloat(primitive.color.a))
			render(primitive: primitive)
		}
		
		glDisable(GLenum(GL_BLEND))
	}
}
