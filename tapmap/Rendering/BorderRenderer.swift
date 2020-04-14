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
	var actualBorderLod: Int = 10
	var wantedBorderLod: Int
	
	let borderQueue: DispatchQueue
	var pendingBorders: Set<Int> = []

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
		
		borderQueue = DispatchQueue(label: "Border construction", qos: .userInitiated, attributes: .concurrent)
		wantedBorderLod = GeometryStreamer.shared.wantedLodLevel
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
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		for borderHash in updateSet {
			let loddedBorderHash = borderHashLodKey(borderHash, atLod: lodLevel)
			if borderPrimitives[loddedBorderHash] == nil {
				borderLodMiss = true
				if pendingBorders.contains(loddedBorderHash) {
					continue
				}
				
				if let tessellation = streamer.tessellation(for: borderHash, atLod: lodLevel) {
					pendingBorders.insert(loddedBorderHash)
					borderQueue.async {
						let borderOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: 1.0, outerExtent: 0.1) }
						let countourVertices = tessellation.contours.map({$0.vertices})
						let outlineGeometry: RegionContours = countourVertices.map(borderOutline)

						// Create the render primitive and update book-keeping on the OpenGL/main thread
						DispatchQueue.main.async {
							let outlinePrimitive = OutlineRenderPrimitive(contours: outlineGeometry,
																														ownerHash: 0,
																														debugName: "Border \(borderHash)@\(lodLevel)")
							self.borderPrimitives[loddedBorderHash] = outlinePrimitive
							self.pendingBorders.remove(loddedBorderHash)
						}
					}
				}
			}
		}
		if !borderLodMiss && actualBorderLod != streamer.wantedLodLevel {
			actualBorderLod = streamer.wantedLodLevel
			print("Border renderer switched to LOD\(actualBorderLod)")
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
		
		let components : [GLfloat] = [1.0, 1.0, 1.0, 1.0]
		glUniform4f(borderUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		glUniform1f(borderUniforms.width, borderWidth)
		
		let loddedBorderKeys = visibleSet.map { borderHashLodKey($0, atLod: actualBorderLod) }
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
