//
//  GeoRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import OpenGLES
import GLKit

// FIXME: very drawcall-heavy. Can be done in one drawcall with fatter vertices.

protocol Renderable {
	func renderPrimitive() -> RenderPrimitive
}

class RenderPrimitive {
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	let indexCount: GLsizei
	let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
	
	init(vertices: [Vertex], indices: [UInt32], color c: (r: Float, g: Float, b: Float, a: Float)) {
		color = c
		
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		glBufferData(GLenum(GL_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<Vertex>.size * vertices.count),
								 vertices,
		             GLenum(GL_STATIC_DRAW))
		
		indexCount = GLsizei(indices.count)
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<GLint>.size * indices.count),
								 indices,
		             GLenum(GL_STATIC_DRAW))
	}
	
	deinit {
		glDeleteBuffers(1, &indexBuffer)
		glDeleteBuffers(1, &vertexBuffer)
	}
}

func render(primitive: RenderPrimitive) {
	glEnableClientState(GLenum(GL_VERTEX_ARRAY))
	glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
	
	glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), primitive.indexBuffer)
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	
	glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												8, BUFFER_OFFSET(0))
	
	var components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
	glUniform4f(uniforms[UNIFORM_COLOR], GLfloat(components[0]), GLfloat(components[1]), GLfloat(components[2]), GLfloat(components[3]))
	
	glDrawElements(GLenum(GL_TRIANGLES),
								 primitive.indexCount,
								 GLenum(GL_UNSIGNED_INT),
								 BUFFER_OFFSET(0))
}
