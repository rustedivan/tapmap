//
//  EffectRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-03-24.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

struct RegionEffect {
	let primitive: RenderPrimitive
	let center: Vertex
	let startTime: Date
	let duration: TimeInterval
	var progress : Double {
		return Date().timeIntervalSince(startTime) / duration
	}
}

class EffectRenderer {
	var runningEffects : [RegionEffect]
	let openingProgram: GLuint
	let effectUniforms : (modelViewMatrix: GLint, color: GLint, progress: GLint, scaleInPlaceMatrix: GLint)
	
	init?() {
		openingProgram = loadShaders(shaderName: "OpeningShader")
		guard openingProgram != 0 else {
			print("Failed to load opening shaders")
			return nil
		}
		
		effectUniforms.modelViewMatrix = glGetUniformLocation(openingProgram, "modelViewProjectionMatrix")
		effectUniforms.color = glGetUniformLocation(openingProgram, "regionColor")
		effectUniforms.progress = glGetUniformLocation(openingProgram, "progress")
		effectUniforms.scaleInPlaceMatrix = glGetUniformLocation(openingProgram, "scaleInPlaceMatrix")
		
		runningEffects = []
	}
	
	deinit {
		if openingProgram != 0 {
			glDeleteProgram(openingProgram)
		}
	}
	
	func addOpeningEffect(for primitive: RenderPrimitive, at midpoint: Vertex) {
		runningEffects.append(RegionEffect(primitive: primitive, center: midpoint, startTime: Date(), duration: 1.0))
	}
	
	func updatePrimitives() {
		runningEffects = runningEffects.filter {
			$0.startTime + $0.duration > Date()
		}
	}
	
	func renderWorld(geoWorld: GeoWorld, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render opening effect")
		glUseProgram(openingProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(effectUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		glEnable(GLenum(GL_BLEND))
		glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
		
		for effect in runningEffects {
			let primitive = effect.primitive
			var components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
			glUniform4f(effectUniforms.color,
									GLfloat(components[0]),
									GLfloat(components[1]),
									GLfloat(components[2]),
									GLfloat(components[3]))
			
			glUniform1f(effectUniforms.progress, GLfloat(effect.progress))
			
			// Construct matrix for scaling in place on top of `center`
			let scale = Float(1.0 + effect.progress * 0.5);
			var scaleInPlaceMatrix = GLKMatrix4Identity;
			scaleInPlaceMatrix = GLKMatrix4Translate(scaleInPlaceMatrix, effect.center.x, effect.center.y, 0.0)
			scaleInPlaceMatrix = GLKMatrix4Scale(scaleInPlaceMatrix, scale, scale, 0.0)
			scaleInPlaceMatrix = GLKMatrix4Translate(scaleInPlaceMatrix, -effect.center.x, -effect.center.y, 0.0)
			withUnsafePointer(to: &scaleInPlaceMatrix, {
				$0.withMemoryRebound(to: Float.self, capacity: 16, {
					glUniformMatrix4fv(effectUniforms.scaleInPlaceMatrix, 1, 0, $0)
				})
			})
			
			render(primitive: primitive)
		}
		
		glDisable(GLenum(GL_BLEND))
		glPopGroupMarkerEXT()
	}
}

