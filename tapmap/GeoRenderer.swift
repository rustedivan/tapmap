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

class GeoBorderRenderer {
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	
	init(continent: GeoContinent) {
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		var verticesCopy = continent.borderVertices
		glBufferData(GLenum(GL_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<Vertex>.size * verticesCopy.count),
								 &verticesCopy,
								 GLenum(GL_STATIC_DRAW))
		
		// Linear index array for now until we tessellate regions
		var indicesCopy = Array(0..<GLuint(continent.borderVertices.count))
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<GLint>.size * indicesCopy.count),
		             &indicesCopy,
		             GLenum(GL_STATIC_DRAW))
	}
	
	deinit {
		glDeleteBuffers(1, &indexBuffer)
		glDeleteBuffers(1, &vertexBuffer)
	}
	
	func render(regions: [GeoRegion]) {
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		glLineWidth(2.0)
		
		glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
		glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
		
		for r in regions {
			var components : [GLfloat] = [1.0, 1.0, 1.0, 1.0]
			glUniform4f(uniforms[UNIFORM_COLOR], GLfloat(components[0]), GLfloat(components[1]), GLfloat(components[2]), GLfloat(components[3]))
			for f in r.features {
				renderFeature(f)
			}
		}
	}
	
	func renderFeature(_ feature: GeoFeature) {
		
		glDrawElements(GLenum(GL_LINE_LOOP),
		               GLsizei(feature.vertexRange.count),
		               GLenum(GL_UNSIGNED_INT),
		               BUFFER_OFFSET(feature.vertexRange.start * 4))
	}
}


// FIXME: very drawcall-heavy. Can be done in one drawcall with fatter vertices.
// Possible to draw each region with barycenter and national colors in vertex buffer.
// Can run vertex transforms from that barycenter and a progression in uniforms

class GeoRegionRenderer {
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	let indexCount: GLsizei
	
	init?(region: GeoRegion) {
		guard let tessellation = region.tessellation else {
			return nil
		}
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		var verticesCopy = tessellation.vertices
		glBufferData(GLenum(GL_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<Vertex>.size * verticesCopy.count),
		             &verticesCopy,
		             GLenum(GL_STATIC_DRAW))
		
		indexCount = GLsizei(tessellation.indices.count)
		var indicesCopy = tessellation.indices
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<GLint>.size * indicesCopy.count),
		             &indicesCopy,
		             GLenum(GL_STATIC_DRAW))
	}
	
	deinit {
		glDeleteBuffers(1, &indexBuffer)
		glDeleteBuffers(1, &vertexBuffer)
	}
	
	func render(region: GeoRegion) {
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
		glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
		
		let c = region.color
		var components : [GLfloat] = [c.r, c.g, c.b, 1.0]
		glUniform4f(uniforms[UNIFORM_COLOR], GLfloat(components[0]), GLfloat(components[1]), GLfloat(components[2]), GLfloat(components[3]))
		
		glDrawElements(GLenum(GL_TRIANGLES),
		               indexCount,
		               GLenum(GL_UNSIGNED_INT),
		               BUFFER_OFFSET(0))
	}
}
