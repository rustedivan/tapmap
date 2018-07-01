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

class GeoRegionRenderer {
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	let indexCount: GLsizei
	var aabbBuffer: GLuint = 2
	
	init(region: GeoRegion) {
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		var verticesCopy = region.geometry.vertices
		glBufferData(GLenum(GL_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<Vertex>.size * verticesCopy.count),
		             &verticesCopy,
		             GLenum(GL_STATIC_DRAW))
		
		indexCount = GLsizei(region.geometry.indices.count)
		var indicesCopy = region.geometry.indices
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<GLint>.size * indicesCopy.count),
		             &indicesCopy,
		             GLenum(GL_STATIC_DRAW))
		
		let aabb = region.geometry.aabb
		var aabbVertices = [Vertex(v: (aabb.minX, aabb.minY)),
												Vertex(v: (aabb.maxX, aabb.minY)),
												Vertex(v: (aabb.maxX, aabb.maxY)),
												Vertex(v: (aabb.minX, aabb.maxY))]
		
		glGenBuffers(1, &aabbBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), aabbBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<Vertex>.size * 4),
								 &aabbVertices,
								 GLenum(GL_STATIC_DRAW))
	}
	
	deinit {
		glDeleteBuffers(1, &indexBuffer)
		glDeleteBuffers(1, &vertexBuffer)
	}
	
	func render(region: GeoRegion) {
		glEnableClientState(GLenum(GL_VERTEX_ARRAY))
		glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
		
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
		
		var hashKey = 5381;
		for c in region.name {
			hashKey = (hashKey & 33) + hashKey + (c.hashValue % 32)
		}
		
		let r = Float(hashKey % 1000) / 1000.0
		let g = Float(hashKey % 1000) / 1000.0
		let b = Float(hashKey % 1000) / 1000.0
		
		let c = (r: 0.1 * r as Float, g: 0.6 * g as Float, b: 0.3 * b as Float)
		var components : [GLfloat] = [c.r, c.g, c.b, 1.0]
		glUniform4f(uniforms[UNIFORM_COLOR], GLfloat(components[0]), GLfloat(components[1]), GLfloat(components[2]), GLfloat(components[3]))
		
		glDrawElements(GLenum(GL_TRIANGLES),
		               indexCount,
		               GLenum(GL_UNSIGNED_INT),
		               BUFFER_OFFSET(0))
		
		
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), aabbBuffer)
		
		glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
		
		let c2 = (r: 1.0 as Float, g: 1.0 as Float, b: 0.0 as Float)
		var components2 : [GLfloat] = [c2.r, c2.g, c2.b, 1.0]
		glUniform4f(uniforms[UNIFORM_COLOR], GLfloat(components2[0]), GLfloat(components2[1]), GLfloat(components2[2]), GLfloat(components2[3]))
		
		glDrawArrays(GLenum(GL_LINE_LOOP), 0, 4)
		
		glDisableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
		glDisableClientState(GLenum(GL_VERTEX_ARRAY))
	}
}
