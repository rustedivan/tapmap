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
	let mapUniforms : (modelViewMatrix: GLint, color: GLint)
	
	init?(withGeoWorld geoWorld: GeoWorld) {
		mapProgram = loadShaders(shaderName: "MapShader")
		guard mapProgram != 0 else {
			print("Failed to load map shaders")
			return nil
		}
		mapUniforms.modelViewMatrix = glGetUniformLocation(mapProgram, "modelViewProjectionMatrix")
		mapUniforms.color = glGetUniformLocation(mapProgram, "regionColor")
		
		let userState = AppDelegate.sharedUserState
		
		let openContinents = geoWorld.continents.filter { userState.regionOpened(r: $0.geography) }
		let closedContinents = geoWorld.continents.subtracting(openContinents)
		
		let countries = Set(openContinents.flatMap { $0.countries })
		let openCountries = countries.filter { userState.regionOpened(r: $0.geography) }
		let closedCountries = countries.subtracting(openCountries)
		
		// Finally form a list of box-collided regions of opened countries
		let regions = Set(openCountries.flatMap { $0.regions })
		let openRegions = regions.filter { userState.regionOpened(r: $0) }
		let closedRegions = regions.subtracting(openRegions)
		
		// Now we have three sets of closed geographies that we could open
		var candidateGeographies: Set<GeoRegion> = []
		candidateGeographies.formUnion(closedContinents.map { $0.geography })
		candidateGeographies.formUnion(closedCountries.map { $0.geography })
		candidateGeographies.formUnion(closedRegions)
		
		// Collect a flat list of all primitives and their hash keys
		let hashedPrimitivesList = candidateGeographies.map { ($0.hashValue, $0.renderPrimitive())}
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		regionPrimitives = Dictionary(hashedPrimitivesList, uniquingKeysWith: { (l, r) in l })
	}
	
	deinit {
		if mapProgram != 0 {
			glDeleteProgram(mapProgram)
		}
	}
	
	func updatePrimitives(forGeography geography: GeoRegion, withSubregions regions: Set<GeoRegion>) {
		if AppDelegate.sharedUserState.regionOpened(r: geography) {
			regionPrimitives.removeValue(forKey: geography.hashValue)
			
			let hashedPrimitives = regions.map {
				($0.hashValue, $0.renderPrimitive())
			}
			regionPrimitives.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in l })
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
		
		for primitive in regionPrimitives.values {
			var components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
			glUniform4f(mapUniforms.color,
									GLfloat(components[0]),
									GLfloat(components[1]),
									GLfloat(components[2]),
									GLfloat(components[3]))
			render(primitive: primitive)
		}
		glPopGroupMarkerEXT()
	}
}

