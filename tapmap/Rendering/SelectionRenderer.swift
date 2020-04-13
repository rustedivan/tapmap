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
	var outlinePrimitive: OutlineRenderPrimitive?
	let outlineProgram: GLuint
	let outlineUniforms : (modelViewMatrix: GLint, color: GLint, width: GLint)
	var outlineWidth: Float
	
	init?() {
		outlineWidth = 0.0
		
		outlineProgram = loadShaders(shaderName: "EdgeShader")
		guard outlineProgram != 0 else {
			print("Failed to load outline shaders")
			return nil
		}
		
		outlineUniforms.modelViewMatrix = glGetUniformLocation(outlineProgram, "modelViewProjectionMatrix")
		outlineUniforms.color = glGetUniformLocation(outlineProgram, "edgeColor")
		outlineUniforms.width = glGetUniformLocation(outlineProgram, "edgeWidth")
	}
	
	deinit {
		if outlineProgram != 0 {
			glDeleteProgram(outlineProgram)
		}
	}
	
	func select(regionHash: RegionHash) {
		guard let tessellation = GeometryStreamer.shared.tessellation(for: regionHash) else { return }
		
		let thinOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, width: 0.2) }
		let countourVertices = tessellation.contours.map({$0.vertices})
		let outlineGeometry: RegionContours = countourVertices.map(thinOutline)
		
		outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																							ownerHash: 0,
																							debugName: "Selection contours")
	}
	
	func clear() {
		outlinePrimitive = nil
	}
	
	func updateStyle(zoomLevel: Float) {
		outlineWidth = 0.2 / zoomLevel
	}
	
	func renderSelection(inProjection projection: GLKMatrix4) {
		guard let primitive = outlinePrimitive else { return }
		glPushGroupMarkerEXT(0, "Render outlines")
		glUseProgram(outlineProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(outlineUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		let components : [GLfloat] = [0.0, 0.0, 0.0, 1.0]
		glUniform4f(outlineUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		glUniform1f(outlineUniforms.width, outlineWidth)
		render(primitive: primitive)
	
		glPopGroupMarkerEXT()
	}
}
