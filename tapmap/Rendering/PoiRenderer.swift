//
//  PoiRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit

struct PoiPlane: Hashable {
	let primitive: IndexedRenderPrimitive
	let rank: Int
	var ownerHash: Int { return primitive.ownerHash }
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(primitive.ownerHash)
		hasher.combine(rank)
	}
	
	static func == (lhs: PoiPlane, rhs: PoiPlane) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
}

class PoiRenderer {
	enum Visibility {
		static let FadeInDuration = 1.0
		static let FadeOutDuration = 0.75
		case fadeIn(startTime: Date)
		case fadeOut(startTime: Date)
		case visible
		
		func alpha() -> Double {
			switch self {
			case .fadeIn(let startTime):
				let progress = Date().timeIntervalSince(startTime) / PoiRenderer.Visibility.FadeInDuration
				return min(progress, 1.0)
			case .fadeOut(let startTime):
				let progress = Date().timeIntervalSince(startTime) / PoiRenderer.Visibility.FadeOutDuration
				return max(1.0 - progress, 0.0)
			case .visible: return 1.0
			}
		}
	}
	var regionPrimitives : [PoiPlane]
	var poiVisibility: [Int : Visibility]
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
		
		let visibleContinentPoiPlanes = closedContinents.flatMap { $0.poiRenderPlanes() }
		let visibleCountryPoiPlanes = closedCountries.flatMap { $0.poiRenderPlanes() }
		let visibleRegionPoiPlanes = closedRegions.flatMap { $0.poiRenderPlanes() }
		
		regionPrimitives = visibleContinentPoiPlanes + visibleCountryPoiPlanes + visibleRegionPoiPlanes
		
		// Create rendering parameters for all currently visible POI planes
		poiVisibility = Dictionary(uniqueKeysWithValues: regionPrimitives.compactMap { (poiPlane) in
			let startsVisible = Float(poiPlane.rank) <= 1.0
			return startsVisible ? (poiPlane.hashValue, Visibility.fadeIn(startTime: Date())) : nil
		})
	}
	
	deinit {
		if poiProgram != 0 {
			glDeleteProgram(poiProgram)
		}
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>)
		where T.SubType : GeoPlaceContainer {
		if AppDelegate.sharedUserState.placeVisited(node) {
			let removedRegionsHash = node.hashValue
			regionPrimitives = regionPrimitives.filter { $0.ownerHash != removedRegionsHash }
			let subregionPrimitives = subRegions.flatMap { $0.poiRenderPlanes() }
			regionPrimitives.append(contentsOf: subregionPrimitives)
			
			for newRegion in subregionPrimitives {
				if Float(newRegion.rank) <= rankThreshold {
					poiVisibility.updateValue(.visible, forKey: newRegion.hashValue)
				}
			}
		}
	}
	
	func updateFades() {
		let now = Date()
		for (key, p) in poiVisibility {
			switch(p) {
			case .fadeIn(let startTime):
				if startTime.addingTimeInterval(1.0) < now {
					poiVisibility.updateValue(.visible, forKey: key)
				}
			case .fadeOut(let startTime):
				if startTime.addingTimeInterval(1.0) < now {
					poiVisibility.removeValue(forKey: key)
				}
				break
			default: break
			}
		}
	}
	
	func updateZoomThreshold(viewZoom: Float) {
		let previousPois = Set(regionPrimitives.filter { Float($0.rank) <= rankThreshold })
		let visiblePois = Set(regionPrimitives.filter { Float($0.rank) <= viewZoom })

		let poisToHide = previousPois.subtracting(visiblePois)	// Culled this frame
		let poisToShow = visiblePois.subtracting(previousPois) // Shown this frame
		
		for p in poisToHide {
			poiVisibility.updateValue(.fadeOut(startTime: Date()), forKey: p.hashValue)
		}
		
		for p in poisToShow {
			poiVisibility.updateValue(.fadeIn(startTime: Date()), forKey: p.hashValue)
		}
		
		rankThreshold = viewZoom
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
		
		for poiPlane in regionPrimitives {
			guard let parameters = poiVisibility[poiPlane.hashValue] else { continue }
			glUniform1f(poiUniforms.progress, GLfloat(parameters.alpha()))
			render(primitive: poiPlane.primitive)
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
																						ownerHash: container.hashValue,	// The hash of the owning region
																						debugName: "\(container.name) - poi plane @ \(rank)")
		return PoiPlane(primitive: primitive, rank: rank)
	}
}

extension GeoPlaceContainer where Self : GeoIdentifiable {
	func poiRenderPlanes() -> [PoiPlane] {
		return sortPlacesIntoPoiPlanes(places, in: self);
	}
}
