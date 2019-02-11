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
		
		let openContinents = geoWorld.continents.filter { userState.placeVisited($0.geography) }
		
		let countries = Set(openContinents.flatMap { $0.countries })
		let openCountries = countries.filter { userState.placeVisited($0.geography) }
		let closedCountries = countries.subtracting(openCountries)
		
		let regions = Set(openCountries.flatMap { $0.regions })
		let openRegions = regions.filter { userState.placeVisited($0) }
		let closedRegions = regions.subtracting(openRegions)
		
		let visibleCountryPoiPlanes = closedCountries.map { ($0.hashValue, createPoiPlane($0.places, debugName: $0.name)) }
		let visibleRegionPoiPlanes = closedRegions.map { ($0.hashValue, createPoiPlane($0.places, debugName: $0.name)) }
		let visiblePoiPlanes = visibleCountryPoiPlanes + visibleRegionPoiPlanes
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		regionPrimitives = Dictionary(visiblePoiPlanes, uniquingKeysWith: { (l, r) in l } )
	}
	
	deinit {
		if poiProgram != 0 {
			glDeleteProgram(poiProgram)
		}
	}
	
	func updatePrimitives(forRegion region: GeoRegion, withSubregions regions: Set<GeoRegion>) {
		if AppDelegate.sharedUserState.placeVisited(region) {
			regionPrimitives.removeValue(forKey: region.hashValue)
			
			let hashedPrimitives = regions.map { ($0.hashValue, createPoiPlane($0.places, debugName: $0.name)) }
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

fileprivate func createPoiPlane(_ places: Set<GeoPlace>, debugName: String) -> RenderPrimitive {
	let vertices = places.reduce([]) { (accumulator: [Vertex], place: GeoPlace) in
		let size = 0.2 / 2.0
		let v0 = Vertex(0.0, size)
		let v1 = Vertex(size, 0.0)
		let v2 = Vertex(0.0, -size)
		let v3 = Vertex(-size, 0.0)
		let verts = [v0, v1, v2, v3].map { $0 + place.location }
		return accumulator + verts
	}
	
	let triangleRange = 0..<UInt32(places.count * 2)
	let indices = triangleRange.reduce([]) { (accumulator: [UInt32], triIndex: UInt32) in
		let quadIndices: [UInt32] = [0, 2, 1, 0, 3, 2]	// Build two triangles from the four quad vertices
		let vertexOffset = triIndex * 4
		let offsetIndices = quadIndices.map { $0 + vertexOffset }
		return accumulator + offsetIndices
	}
	
	return RenderPrimitive(vertices: vertices,
												 indices: indices,
												 color: (r: 1.0, g: 0.0, b: 0.0, a: 0.7),
												 debugName: debugName)
}
