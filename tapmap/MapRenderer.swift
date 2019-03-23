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
	var regionPrimitives : [Int : RenderPrimitive]
	let mapProgram: GLuint
	let mapUniforms : (modelViewMatrix: GLint, color: GLint, highlighted: GLint, time: GLint)
	
	init?(withGeoWorld geoWorld: GeoWorld) {
		mapProgram = loadShaders(shaderName: "MapShader")
		guard mapProgram != 0 else {
			print("Failed to load map shaders")
			return nil
		}
		
		mapUniforms.modelViewMatrix = glGetUniformLocation(mapProgram, "modelViewProjectionMatrix")
		mapUniforms.color = glGetUniformLocation(mapProgram, "regionColor")
		mapUniforms.highlighted = glGetUniformLocation(mapProgram, "highlighted")
		mapUniforms.time = glGetUniformLocation(mapProgram, "time")
		
		let userState = AppDelegate.sharedUserState
		
		let openContinents = geoWorld.children.filter { userState.placeVisited($0) }
		let closedContinents = geoWorld.children.subtracting(openContinents)
		
		let countries = Set(openContinents.flatMap { $0.children })
		let openCountries = countries.filter { userState.placeVisited($0) }
		let closedCountries = countries.subtracting(openCountries)
		
		// Finally form a list of box-collided regions of opened countries
		let regions = Set(openCountries.flatMap { $0.children })
		let openRegions = regions.filter { userState.placeVisited($0) }
		let closedRegions = regions.subtracting(openRegions)
		
		// Now we have three sets of closed geographies that we could open
		// Collect a flat list of all primitives and their hash keys
		let hashedPrimitivesList = closedContinents.map { ($0.hashValue, $0.renderPrimitive()) } +
															 closedCountries.map { ($0.hashValue, $0.renderPrimitive()) } +
															 closedRegions.map { ($0.hashValue, $0.renderPrimitive()) }
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		regionPrimitives = Dictionary(hashedPrimitivesList, uniquingKeysWith: { (l, r) in print("Inserting bad"); return l })
	}
	
	deinit {
		if mapProgram != 0 {
			glDeleteProgram(mapProgram)
		}
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>) {
		if AppDelegate.sharedUserState.placeVisited(node) {
			regionPrimitives.removeValue(forKey: node.hashValue)

			let hashedPrimitives = subRegions.map {
				($0.hashValue, $0.renderPrimitive())
			}
			regionPrimitives.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in print("Replacing"); return l })
		}
	}
	
	func renderWorld(geoWorld: GeoWorld, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render world")
		glUseProgram(mapProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(mapUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		glUniform1f(mapUniforms.time, 0.0)
		
		for primitive in regionPrimitives.values {
			var components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
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

