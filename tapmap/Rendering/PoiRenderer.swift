//
//  PoiRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

struct PoiPlane {
	let primitive: IndexedRenderPrimitive
	var toggleTime: Date
	let rank: Int
	var progress : Double {
		return min(max(0.0, Date().timeIntervalSince(toggleTime), 0.0), 1.0)
	}
}

class PoiRenderer {
	var regionPrimitives : [Int : [PoiPlane]]
	let poiProgram: GLuint
	let poiUniforms : (modelViewMatrix: GLint, color: GLint, rankThreshold: GLint, progress: GLint)
	var rankThreshold: Float = 1.0
	
	init?(withGeoWorld geoWorld: GeoWorld) {
		poiProgram = loadShaders(shaderName: "PoiShader")
		guard poiProgram != 0 else {
			print("Failed to load POI shaders")
			return nil
		}
		poiUniforms.modelViewMatrix = glGetUniformLocation(poiProgram, "modelViewProjectionMatrix")
		poiUniforms.color = glGetUniformLocation(poiProgram, "poiColor")
		poiUniforms.rankThreshold = glGetUniformLocation(poiProgram, "rankThreshold")
		poiUniforms.progress = glGetUniformLocation(poiProgram, "progress")
		
		let userState = AppDelegate.sharedUserState
		
		let openContinents = geoWorld.children.filter { userState.placeVisited($0) }
		let closedContinents = geoWorld.children.subtracting(openContinents)
		
		let countries = Set(openContinents.flatMap { $0.children })
		let openCountries = countries.filter { userState.placeVisited($0) }
		let closedCountries = countries.subtracting(openCountries)
		
		let regions = Set(openCountries.flatMap { $0.children })
		let openRegions = regions.filter { userState.placeVisited($0) }
		let closedRegions = regions.subtracting(openRegions)
		
		let visibleContinentPoiPlanes = closedContinents.map { ($0.hashValue, $0.poiRenderPlanes()) }
		let visibleCountryPoiPlanes = closedCountries.map { ($0.hashValue, $0.poiRenderPlanes()) }
		let visibleRegionPoiPlanes = closedRegions.map { ($0.hashValue, $0.poiRenderPlanes()) }
		let visiblePoiPlanes = visibleContinentPoiPlanes + visibleCountryPoiPlanes + visibleRegionPoiPlanes
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		regionPrimitives = Dictionary(visiblePoiPlanes, uniquingKeysWith: { (l, r) in l + r } )
	}
	
	deinit {
		if poiProgram != 0 {
			glDeleteProgram(poiProgram)
		}
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>)
		where T.SubType : GeoPlaceContainer {
		if AppDelegate.sharedUserState.placeVisited(node) {
			regionPrimitives.removeValue(forKey: node.hashValue)

			let hashedPrimitives = subRegions.map { ($0.hashValue, $0.poiRenderPlanes()) }
			regionPrimitives.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in l + r })
		}
	}
	
	func renderWorld(geoWorld: GeoWorld, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render POI plane")
		glUseProgram(poiProgram)
		glEnable(GLenum(GL_BLEND))
		glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(poiUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		let components : [GLfloat] = [1.0, 1.0, 1.0, 1.0]
		glUniform4f(poiUniforms.color,
								GLfloat(components[0]),
								GLfloat(components[1]),
								GLfloat(components[2]),
								GLfloat(components[3]))
		glUniform1f(poiUniforms.rankThreshold, rankThreshold)
		
		for poiPlanes in regionPrimitives.values {
			_ = poiPlanes.map { (poiPlane) in
				glUniform1f(poiUniforms.progress, GLfloat(poiPlane.progress))
				render(primitive: poiPlane.primitive)
			}
		}
		glDisable(GLenum(GL_BLEND))
		glPopGroupMarkerEXT()
	}
}

// MARK: Generating POI planes
func bucketPlaceMarkers(places: Set<GeoPlace>) -> [Int: Set<GeoPlace>] {
	var bins: [Int: Set<GeoPlace>] = [:]
	for place in places {
		if bins[place.rank] != nil {
			bins[place.rank]!.insert(place)
		} else {
			bins[place.rank] = Set<GeoPlace>([place])
		}
	}
	return bins
}

func buildPlaceMarkers(places: Set<GeoPlace>) -> ([Vertex], [UInt32], [Float]) {
	let vertices = places.reduce([]) { (accumulator: [Vertex], place: GeoPlace) in
		let size = log10(Float(place.rank) / 10.0)
		let v0 = Vertex(0.0, size)
		let v1 = Vertex(size, 0.0)
		let v2 = Vertex(0.0, -size)
		let v3 = Vertex(-size, 0.0)
		let verts = [v0, v1, v2, v3].map { $0 + place.location }
		return accumulator + verts
	}
	
	let quadRange = 0..<UInt32(places.count)
	let indices = quadRange.reduce([]) { (accumulator: [UInt32], quadIndex: UInt32) in
		let quadIndices: [UInt32] = [0, 2, 1, 0, 3, 2]	// Build two triangles from the four quad vertices
		let vertexOffset = quadIndex * 4
		let offsetIndices = quadIndices.map { $0 + vertexOffset }
		return accumulator + offsetIndices
	}
	
	let scalars = places.reduce([]) { (accumulator: [Float], place: GeoPlace) in
		accumulator + Array(repeating: Float(place.rank), count: 4)
	}
	
	return (vertices, indices, scalars)
}

func sortPlacesIntoPoiPlanes<T: GeoIdentifiable>(_ places: Set<GeoPlace>, in container: T) -> [PoiPlane] {
	let rankedPlaces = bucketPlaceMarkers(places: places)
	return rankedPlaces.map { (rank, places) in
		let (vertices, indices, scalars) = buildPlaceMarkers(places: places)
		let primitive = IndexedRenderPrimitive(vertices: vertices,
																						indices: indices, scalarAttribs: scalars,
																						color: rank.hashColor.tuple(),
																						ownerHash: container.hashValue,
																						debugName: "\(container.name) - poi plane @ \(rank)")
		return PoiPlane(primitive: primitive, toggleTime: Date(), rank: rank)
	}
}
	
extension GeoRegion {
	func poiRenderPlanes() -> [PoiPlane] {
		return sortPlacesIntoPoiPlanes(places, in: self);
	}
}

extension GeoCountry {
	func poiRenderPlanes() -> [PoiPlane] {
		return sortPlacesIntoPoiPlanes(places, in: self);
	}
}

extension GeoContinent {
	func poiRenderPlanes() -> [PoiPlane] {
		return sortPlacesIntoPoiPlanes(places, in: self);
	}
}

