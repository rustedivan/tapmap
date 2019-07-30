//
//  ArrayedRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES

class ArrayedRenderPrimitive {
	let ownerHash: Int
	
	var vertexBuffer: GLuint = 0
	let elementCount: GLsizei
	
	let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
	let name: String
	
	init(vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
		color = c
		
		ownerHash = hash
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
		
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), vertexBuffer, 0, "\(debugName).vertices")
	}
	
	deinit {
		glDeleteBuffers(1, &vertexBuffer)
	}
}

func render(primitive: ArrayedRenderPrimitive) {
	guard primitive.elementCount > 0 else {
		return
	}
	
	glEnableClientState(GLenum(GL_VERTEX_ARRAY))
	glEnableVertexAttribArray(VertexAttribs.position.rawValue)
	
	glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
	
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	// Point out vertex positions
	glVertexAttribPointer(VertexAttribs.position.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<Vertex>.stride), BUFFER_OFFSET(0))
	
	glDrawArrays(GLenum(GL_TRIANGLES),
							 0,
							 primitive.elementCount)
}
