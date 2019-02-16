//
//  PoiRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

class PoiRenderer {
	var regionPrimitives : [Int : RenderPrimitive]
	let poiProgram: GLuint
	let poiUniforms : (modelViewMatrix: GLint, color: GLint)
	
	init?(withGeoWorld geoWorld: GeoWorld) {
		poiProgram = loadShaders(shaderName: "PoiShader")
		guard poiProgram != 0 else {
			print("Failed to load POI shaders")
			return nil
		}
		poiUniforms.modelViewMatrix = glGetUniformLocation(poiProgram, "modelViewProjectionMatrix")
		poiUniforms.color = glGetUniformLocation(poiProgram, "poiColor")
		
		let userState = AppDelegate.sharedUserState
		
		let openContinents = geoWorld.children.filter { userState.placeVisited($0) }
		let closedContinents = geoWorld.children.subtracting(openContinents)
		
		let countries = Set(openContinents.flatMap { $0.children })
		let openCountries = countries.filter { userState.placeVisited($0) }
		let closedCountries = countries.subtracting(openCountries)
		
		let regions = Set(openCountries.flatMap { $0.children })
		let openRegions = regions.filter { userState.placeVisited($0) }
		let closedRegions = regions.subtracting(openRegions)
		
		let visibleContinentPoiPlanes = closedContinents.map { ($0.hashValue, $0.placesRenderPlane()) }
		let visibleCountryPoiPlanes = closedCountries.map { ($0.hashValue, $0.placesRenderPlane()) }
		let visibleRegionPoiPlanes = closedRegions.map { ($0.hashValue, $0.placesRenderPlane()) }
		let visiblePoiPlanes = visibleContinentPoiPlanes + visibleCountryPoiPlanes + visibleRegionPoiPlanes
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		regionPrimitives = Dictionary(visiblePoiPlanes, uniquingKeysWith: { (l, r) in l } )
	}
	
	deinit {
		if poiProgram != 0 {
			glDeleteProgram(poiProgram)
		}
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>) where T.SubType : GeoPlaceContainer {
		if AppDelegate.sharedUserState.placeVisited(node) {
			regionPrimitives.removeValue(forKey: node.hashValue)

			let hashedPrimitives = subRegions.map { ($0.hashValue, $0.placesRenderPlane()) }
			regionPrimitives.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in l })
		}
	}
	
	func renderWorld(geoWorld: GeoWorld, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render POI plane")
		glUseProgram(poiProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(poiUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		for primitive in regionPrimitives.values {
			var components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
			glUniform4f(poiUniforms.color,
									GLfloat(components[0]),
									GLfloat(components[1]),
									GLfloat(components[2]),
									GLfloat(components[3]))
			render(primitive: primitive)
		}
		glPopGroupMarkerEXT()
	}
}
