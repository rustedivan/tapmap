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
	var outlinePrimitives: [RenderPrimitive]
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
	
	func select(geometry tessellation: GeoTessellated) {
		let thinOutline = { (outline: [Vertex]) in generateOutlineGeometry(outline: outline, width: 1.0) }
		
		let countourVertices = tessellation.contours.map({$0.vertices})
		let outlineGeometry = countourVertices.map(thinOutline)
		
		outlinePrimitives = outlineGeometry.map( { (contour: [Vertex]) -> RenderPrimitive in
			return RenderPrimitive(vertices: contour,
														 color: (r: 0, g: 0, b: 0, a: 1),
														 ownerHash: 0,
														 debugName: "Contour")
			})
	}
	
	func clear() {
		outlinePrimitives = []
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
		
//		glEnable(GLenum(GL_BLEND))
//		glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA));
//
		var components : [GLfloat] = [0.0, 0.0, 0.0, 1.0]
		glUniform4f(outlineUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		
		_ = outlinePrimitives.map { render(primitive: $0, mode: .Tristrip) }
	
//		glDisable(GLenum(GL_BLEND))
		glPopGroupMarkerEXT()
	}
}

