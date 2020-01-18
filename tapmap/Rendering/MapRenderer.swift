//
//  MapRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

class MapRenderer {
	var regionPrimitives : [Int : ArrayedRenderPrimitive]
	let mapProgram: GLuint
	let mapUniforms : (modelViewMatrix: GLint, color: GLint, highlighted: GLint, time: GLint)
	
	init?(withVisibleContinents continents: [Int: GeoContinent],
				countries: [Int: GeoCountry],
				regions: [Int: GeoRegion]) {
		mapProgram = loadShaders(shaderName: "MapShader")
		guard mapProgram != 0 else {
			print("Failed to load map shaders")
			return nil
		}
		
		mapUniforms.modelViewMatrix = glGetUniformLocation(mapProgram, "modelViewProjectionMatrix")
		mapUniforms.color = glGetUniformLocation(mapProgram, "regionColor")
		mapUniforms.highlighted = glGetUniformLocation(mapProgram, "highlighted")
		mapUniforms.time = glGetUniformLocation(mapProgram, "time")
		
		// Collect a flat list of all primitives and their hash keys
		let continentPrimitives = continents.map { ($0.key, $0.value.renderPrimitive()) }
		let countryPrimitives = countries.map { ($0.key, $0.value.renderPrimitive()) }
		let regionPrimitives = regions.map { ($0.key, $0.value.renderPrimitive()) }
		let allPrimitives = continentPrimitives + countryPrimitives + regionPrimitives
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		self.regionPrimitives = Dictionary(allPrimitives, uniquingKeysWith: { (l, r) in print("Inserting bad"); return l })
	}
	
	deinit {
		if mapProgram != 0 {
			glDeleteProgram(mapProgram)
		}
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>) -> ArrayedRenderPrimitive?
			where T.SubType.PrimitiveType == ArrayedRenderPrimitive {
		let removedPrimitive = regionPrimitives.removeValue(forKey: node.hashValue)
		let hashedPrimitives = subRegions.map {
			($0.hashValue, $0.renderPrimitive())
		}
		regionPrimitives.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in print("Replacing"); return l })
		return removedPrimitive
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
		
		let visiblePrimitives = regionPrimitives.values.filter({ visibleSet.contains($0.ownerHash) })
		for primitive in visiblePrimitives {
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

