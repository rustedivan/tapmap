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
		borderWidth = 0.4 / zoomLevel
	}
	
	func prepareGeometry(for updateSet: Set<Int>) {
		let streamer = GeometryStreamer.shared
		for borderHash in updateSet {
			let loddedBorderHash = borderHashLodKey(borderHash, atLod: streamer.actualLodLevel)
			if borderPrimitives[loddedBorderHash] == nil {
				if let tessellation = streamer.tessellation(for: borderHash) {
					let borderOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: 1.0, outerExtent: 0.1) }
					let countourVertices = tessellation.contours.map({$0.vertices})
					let outlineGeometry: RegionContours = countourVertices.map(borderOutline)
					
					let outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																												ownerHash: 0,
																												debugName: "Border")
					borderPrimitives[loddedBorderHash] = outlinePrimitive
				}
			}
			
		}
	}
	
	func renderBorders(visibleSet: Set<Int>, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render borders")
		glUseProgram(borderProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(borderUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		let components : [GLfloat] = [0.0, 0.0, 1.0, 1.0]
		glUniform4f(borderUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		glUniform1f(borderUniforms.width, borderWidth)
		
		let loddedBorderKeys = visibleSet.map { borderHashLodKey($0, atLod: GeometryStreamer.shared.actualLodLevel) }
		for key in loddedBorderKeys {
			guard let primitive = borderPrimitives[key] else { continue }
			render(primitive: primitive)
		}
		
		glPopGroupMarkerEXT()
	}
	
	func borderHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> Int {
		return "\(regionHash)-\(lod)".hashValue
	}
}
