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

class GeoContinentRenderer {
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	
	init(continent: GeoContinent) {
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		var verticesCopy = continent.vertices
		glBufferData(GLenum(GL_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<Vertex>.size * verticesCopy.count),
								 &verticesCopy,
								 GLenum(GL_STATIC_DRAW))
		
		// Linear index array for now until we tesselate regions
		var indicesCopy = Array(0..<GLuint(continent.vertices.count))
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
		
		glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
		glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
		
		for r in regions {
			let c = r.color
			var components : [GLfloat] = [c.r, c.g, c.b, 1.0]
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
