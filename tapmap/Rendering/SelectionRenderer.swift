//
//  SelectionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

class SelectionRenderer {
	var outlinePrimitives: [OutlineRenderPrimitive]
	let outlineProgram: GLuint
	let outlineUniforms : (modelViewMatrix: GLint, color: GLint)
	
	init?() {
		outlinePrimitives = []
		
		outlineProgram = loadShaders(shaderName: "EdgeShader")
		guard outlineProgram != 0 else {
			print("Failed to load outline shaders")
			return nil
		}
		
		outlineUniforms.modelViewMatrix = glGetUniformLocation(outlineProgram, "modelViewProjectionMatrix")
		outlineUniforms.color = glGetUniformLocation(outlineProgram, "edgeColor")
	}
	
	deinit {
		if outlineProgram != 0 {
			glDeleteProgram(outlineProgram)
		}
	}
	
	func select<T: GeoTessellated>(geometry tessellation: T) {
		let thinOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, width: 0.2) }
				// $ Generate a separate vec2 attrib stream with miter vectors
		let countourVertices = tessellation.contours.map({$0.vertices})
		let outlineGeometry = countourVertices.map(thinOutline)
		
		outlinePrimitives = outlineGeometry.map( { (contour: [Vertex]) -> OutlineRenderPrimitive in
			return OutlineRenderPrimitive(vertices: contour,
																		 color: (r: 0, g: 0, b: 0, a: 1),
																		 ownerHash: 0,
																		 debugName: "Contour")
			})
		
		// $ Create separate attrib buffers
	}
	
	func clear() {
		outlinePrimitives = []
		// $ delete miterBuffers
		// $ clear miterVectors
	}
	
	func renderSelection(inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render outlines")
		glUseProgram(outlineProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(outlineUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		var components : [GLfloat] = [0.0, 0.0, 0.0, 1.0]
		glUniform4f(outlineUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		
		// $ glBindBuffer(GLenum(GL_ARRAY_BUFFER), miterBuffers[i])
		// $ glVertexAttribPointer(Attribs.miterVector.rawValue, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<Vertex>.stride), BUFFER_OFFSET(0))
		_ = outlinePrimitives.map { render(primitive: $0) }
	
		glPopGroupMarkerEXT()
	}
}

