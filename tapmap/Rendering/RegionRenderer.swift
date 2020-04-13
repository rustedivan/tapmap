//
//  RegionRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

class RegionRenderer {
	let mapProgram: GLuint
	let mapUniforms : (modelViewMatrix: GLint, color: GLint, highlighted: GLint, time: GLint)
	
	init?() {
		mapProgram = loadShaders(shaderName: "MapShader")
		guard mapProgram != 0 else {
			print("Failed to load map shaders")
			return nil
		}
		
		mapUniforms.modelViewMatrix = glGetUniformLocation(mapProgram, "modelViewProjectionMatrix")
		mapUniforms.color = glGetUniformLocation(mapProgram, "regionColor")
		mapUniforms.highlighted = glGetUniformLocation(mapProgram, "highlighted")
		mapUniforms.time = glGetUniformLocation(mapProgram, "time")
	}
	
	deinit {
		if mapProgram != 0 {
			glDeleteProgram(mapProgram)
		}
	}
	
	func renderWorld(visibleSet: Set<Int>, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render world")
		glUseProgram(mapProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(mapUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		glUniform1f(mapUniforms.time, 0.0)
		
		// Collect all streamed-in primitives for the currently visible set of non-visited regions
		let renderPrimitives = visibleSet.compactMap { GeometryStreamer.shared.renderPrimitive(for: $0) }
		
		for primitive in renderPrimitives {
			let components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
			glUniform4f(mapUniforms.color,
									GLfloat(components[0]),
									GLfloat(components[1]),
									GLfloat(components[2]),
									GLfloat(components[3]))
			
			let selected = AppDelegate.sharedUIState.selected(primitive.ownerHash)
			glUniform1i(mapUniforms.highlighted, GLint(selected ? 1 : 0))
			render(primitive: primitive)
		}
		glPopGroupMarkerEXT()
	}
}

