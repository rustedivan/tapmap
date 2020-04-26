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
	let outlineProgram: GLuint
	let outlineUniforms : (modelViewMatrix: GLint, color: GLint, width: GLint)
	
	var outlinePrimitive: OutlineRenderPrimitive?
	var outlineWidth: Float
	var lodLevel: Int
	
	init?() {
		outlineWidth = 0.0
		
		outlineProgram = loadShaders(shaderName: "EdgeShader")
		guard outlineProgram != 0 else {
			print("Failed to load outline shaders")
			return nil
		}
		
		lodLevel = GeometryStreamer.shared.wantedLodLevel
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
		let streamer = GeometryStreamer.shared
		guard let tessellation = streamer.tessellation(for: regionHash, atLod: streamer.actualLodLevel) else { return }
		
		let thinOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: 0.5, outerExtent: 0.5) }
		let countourVertices = tessellation.contours.map({$0.vertices})
		let outlineGeometry: RegionContours = countourVertices.map(thinOutline)
		
		outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																							ownerHash: regionHash,
																							debugName: "Selection contours")
	}
	
	func clear() {
		outlinePrimitive = nil
	}
	
	func updateStyle(zoomLevel: Float) {
		outlineWidth = 0.2 / zoomLevel
		
		if let selectionHash = outlinePrimitive?.ownerHash, lodLevel != GeometryStreamer.shared.actualLodLevel {
			select(regionHash: selectionHash)
			lodLevel = GeometryStreamer.shared.actualLodLevel
		}
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
