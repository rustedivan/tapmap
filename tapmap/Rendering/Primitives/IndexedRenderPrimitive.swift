//
//  IndexedRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES

class IndexedRenderPrimitive {
	enum Attribs: GLuint {
		case position = 1
	}
	
	let ownerHash: Int
	
	var vertexBuffer: GLuint = 0
	let elementCount: GLsizei
	
	var indexBuffer: GLuint = 0
	
	let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
	let name: String
	
	// Indexed draw mode
	init(vertices: [Vertex], indices: [UInt32], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
		color = c
		
		ownerHash = hash
		name = debugName
		
		guard !indices.isEmpty else {
			elementCount = 0
			return
		}
		
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		glBufferData(GLenum(GL_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<Vertex>.stride * vertices.count),
								 vertices,
								 GLenum(GL_STATIC_DRAW))
		
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<UInt32>.stride * indices.count),
								 indices,
								 GLenum(GL_STATIC_DRAW))
		elementCount = GLsizei(indices.count)
		
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), vertexBuffer, 0, "\(debugName).vertices")
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), indexBuffer, 0, "\(debugName).indices")
	}
	
	deinit {
		glDeleteBuffers(1, &indexBuffer)
		glDeleteBuffers(1, &vertexBuffer)
	}
}

func render(primitive: IndexedRenderPrimitive) {
	guard primitive.elementCount > 0 else {
		return
	}
	
	glEnableClientState(GLenum(GL_VERTEX_ARRAY))
	glEnableVertexAttribArray(IndexedRenderPrimitive.Attribs.position.rawValue)
	
	glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), primitive.indexBuffer)
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	
	glVertexAttribPointer(IndexedRenderPrimitive.Attribs.position.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<Vertex>.stride), BUFFER_OFFSET(0))
	
	glDrawElements(GLenum(GL_TRIANGLES),
								 primitive.elementCount,
								 GLenum(GL_UNSIGNED_INT),
								 BUFFER_OFFSET(0))
}