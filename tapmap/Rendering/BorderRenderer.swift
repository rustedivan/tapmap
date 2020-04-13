//
//  BorderRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-04-13.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

class BorderRenderer {
	var borderPrimitives: [Int : OutlineRenderPrimitive]
	let borderProgram: GLuint
	let borderUniforms : (modelViewMatrix: GLint, color: GLint, width: GLint)
	var borderWidth: Float
	
	init?() {
		borderWidth = 0.0
		
		borderProgram = loadShaders(shaderName: "EdgeShader")
		guard borderProgram != 0 else {
			print("Failed to load outline shaders")
			return nil
		}
		
		borderUniforms.modelViewMatrix = glGetUniformLocation(borderProgram, "modelViewProjectionMatrix")
		borderUniforms.color = glGetUniformLocation(borderProgram, "edgeColor")
		borderUniforms.width = glGetUniformLocation(borderProgram, "edgeWidth")
		
		borderPrimitives = [:]
	}
	
	deinit {
		if borderProgram != 0 {
			glDeleteProgram(borderProgram)
		}
	}
	
	func updateStyle(zoomLevel: Float) {
		borderWidth = 0.2 / zoomLevel
	}
	
	func renderBorders(inProjection projection: GLKMatrix4) {
		
	}
}
