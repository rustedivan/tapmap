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
	
	func prepareGeometry(visibleContinents: GeoContinentMap, visibleCountries: GeoCountryMap) {
		let streamer = GeometryStreamer.shared
		let lodLevel = streamer.wantedLodLevel
		var borderLodMiss = false
		
		let updateSet: [Int] = Array(visibleContinents.keys) + Array(visibleCountries.keys)
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
						let innerWidth: Float
						let outerWidth: Float
						
						if visibleContinents[borderHash] != nil {
							innerWidth = 0.1
							outerWidth = 3.0
						} else {
							innerWidth = 1.0
							outerWidth = 0.1
						}
						
						let borderOutline = { (outline: [Vertex]) in generateClosedOutlineGeometry(outline: outline, innerExtent: innerWidth, outerExtent: outerWidth) }
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
	
	func renderContinentBorders(_ continents: Set<Int>, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render continent borders")
		glUseProgram(borderProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(borderUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		let components : [GLfloat] = [0.0, 0.5, 0.7, 1.0]
		glUniform4f(borderUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		glUniform1f(borderUniforms.width, borderWidth)
		
		let continentOutlineLod = max(actualBorderLod, 0)	// $ Turn up the limit once border width is under control (set min/max outline width and ramp between )
		let loddedBorderKeys = continents.map { borderHashLodKey($0, atLod: continentOutlineLod) }
		for key in loddedBorderKeys {
			guard let primitive = borderPrimitives[key] else { continue }
			render(primitive: primitive)
		}
		
		glPopGroupMarkerEXT()
	}
	
	func renderCountryBorders(_ countries: Set<Int>, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render country borders")
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
		
		let loddedBorderKeys = countries.map { borderHashLodKey($0, atLod: actualBorderLod) }
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
