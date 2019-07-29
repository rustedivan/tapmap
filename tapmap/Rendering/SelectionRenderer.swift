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
	private var selectedPrimitive: RenderPrimitive?
	let outlineProgram: GLuint
	let outlineUniforms : (modelViewMatrix: GLint, color: GLint)
	
	init?() {
		selectedPrimitive = nil
		
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
		let outline = generateOutlineGeometry(outline: tessellation.contours.first!.vertices, width: 2.0)
		selectedPrimitive = RenderPrimitive(vertices: outline.vertices,
																				indices: outline.indices,
																				color: (r: 0, g: 0, b: 0, a: 1),
																				ownerHash: 0,
																				debugName: "Contour")
	}
	
	func clear() {
		selectedPrimitive = nil
	}
	
	func renderSelection(inProjection projection: GLKMatrix4) {
		guard let primitive = selectedPrimitive else { return }
		glPushGroupMarkerEXT(0, "Render outlines")
		glUseProgram(outlineProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(outlineUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		glEnable(GLenum(GL_BLEND))
		glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA));
		
		var components : [GLfloat] = [0.0, 0.0, 0.0, 1.0]
		glUniform4f(outlineUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		
		render(primitive: primitive)
	
		glDisable(GLenum(GL_BLEND))
		glPopGroupMarkerEXT()
	}
}

