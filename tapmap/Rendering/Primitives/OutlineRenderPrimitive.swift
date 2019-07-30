//
//  OutlineRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES

struct OutlineVertex {
	let x: Float
	let y: Float
	let miterX: Float
	let miterY: Float
	
	init(_ _x: Float, _ _y: Float, miterX _mx: Float, miterY _my: Float) {
		x = _x; y = _y;
		miterX = _mx; miterY = _my;
	}
}

class OutlineRenderPrimitive {
	let ownerHash: Int
	
	var vertexBuffer: GLuint = 0
	let elementCount: GLsizei
	
	let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
	let name: String
	
	init(vertices: [OutlineVertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
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
								 GLsizeiptr(MemoryLayout<OutlineVertex>.stride * vertices.count),
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


func render(primitive: OutlineRenderPrimitive) {
	guard primitive.elementCount > 0 else {
		return
	}
	
	glEnableClientState(GLenum(GL_VERTEX_ARRAY))
	glEnableVertexAttribArray(VertexAttribs.position.rawValue)
	glEnableVertexAttribArray(VertexAttribs.miter.rawValue)
	
	glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
	
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	// Point out vertex positions
	glVertexAttribPointer(VertexAttribs.position.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<OutlineVertex>.stride), BUFFER_OFFSET(0))
	glVertexAttribPointer(VertexAttribs.miter.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<OutlineVertex>.stride), BUFFER_OFFSET(UInt32(MemoryLayout<Float>.stride * 2)))
	
	glDrawArrays(GLenum(GL_TRIANGLE_STRIP),
							 0,
							 primitive.elementCount)
}

