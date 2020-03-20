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
	let primitive: IndexedRenderPrimitive<ScaleVertex>
	let rank: Int
	var ownerHash: Int { return primitive.ownerHash }
	let poiHashes: [Int]
	
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
		static let FadeInDuration = 0.4
		static let FadeOutDuration = 0.2
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
	var poiPlanePrimitives : [PoiPlane]
	var poiVisibility: [Int : Visibility] = [:]
	let poiProgram: GLuint
	let poiUniforms : (modelViewMatrix: GLint, color: GLint, rankThreshold: GLint, progress: GLint, poiBaseSize: GLint)
	var rankThreshold: Float = -1.0
	var poiBaseSize: Float = 0.0
	
	init?(withVisibleContinents continents: [Int: GeoContinent],
				countries: [Int: GeoCountry],
				regions: [Int: GeoRegion]) {
		poiProgram = loadShaders(shaderName: "PoiShader")
		guard poiProgram != 0 else {
			print("Failed to load POI shaders")
			return nil
		}
		poiUniforms.modelViewMatrix = glGetUniformLocation(poiProgram, "modelViewProjectionMatrix")
		poiUniforms.color = glGetUniformLocation(poiProgram, "poiColor")
		poiUniforms.rankThreshold = glGetUniformLocation(poiProgram, "rankThreshold")
		poiUniforms.progress = glGetUniformLocation(poiProgram, "progress")
		poiUniforms.poiBaseSize = glGetUniformLocation(poiProgram, "baseSize")
		
		let visibleContinentPoiPlanes = continents.flatMap { $0.value.poiRenderPlanes() }
		let visibleCountryPoiPlanes = countries.flatMap { $0.value.poiRenderPlanes() }
		let visibleRegionPoiPlanes = regions.flatMap { $0.value.poiRenderPlanes() }
		
		poiPlanePrimitives = visibleContinentPoiPlanes + visibleCountryPoiPlanes + visibleRegionPoiPlanes
	}
	
	deinit {
		if poiProgram != 0 {
			glDeleteProgram(poiProgram)
		}
	}
	
	var activePoiHashes: Set<Int> {
		let visiblePoiPlanes = poiPlanePrimitives.filter { self.poiVisibility[$0.hashValue] != nil }
		return Set(visiblePoiPlanes.flatMap { $0.poiHashes })
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>)
		where T.SubType : GeoPlaceContainer {
		let removedRegionsHash = node.geographyId.hashed
		poiPlanePrimitives = poiPlanePrimitives.filter { $0.ownerHash != removedRegionsHash }
		let subregionPrimitives = subRegions.flatMap { $0.poiRenderPlanes() }
		poiPlanePrimitives.append(contentsOf: subregionPrimitives)
		
		for newRegion in subregionPrimitives {
			if Float(newRegion.rank) <= rankThreshold {
				poiVisibility.updateValue(.visible, forKey: newRegion.hashValue)
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
		// Polynomial curve fit (badly) in Grapher
		let oldRankThreshold = rankThreshold
		rankThreshold = max(0.01 * viewZoom * viewZoom + 0.3 * viewZoom, 1.0)
		
		let previousPois = Set(poiPlanePrimitives.filter { Float($0.rank) <= oldRankThreshold })
		let visiblePois = Set(poiPlanePrimitives.filter { Float($0.rank) <= rankThreshold })

		let poisToHide = previousPois.subtracting(visiblePois)	// Culled this frame
		let poisToShow = visiblePois.subtracting(previousPois) // Shown this frame
		
		for p in poisToHide {
			poiVisibility.updateValue(.fadeOut(startTime: Date()), forKey: p.hashValue)
		}
		
		for p in poisToShow {
			poiVisibility.updateValue(.fadeIn(startTime: Date()), forKey: p.hashValue)
		}
	}
	
	func updateStyle(zoomLevel: Float) {
		let poiScreenSize: Float = 2.0
		poiBaseSize = poiScreenSize / (zoomLevel)
		poiBaseSize += min(zoomLevel * 0.01, 0.1)	// Boost POI sizes a bit when zooming in
	}
	
	func renderWorld(visibleSet: Set<Int>, inProjection projection: GLKMatrix4) {
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
		glUniform1f(poiUniforms.poiBaseSize, poiBaseSize)
		
		let visiblePrimitives = poiPlanePrimitives.filter({ visibleSet.contains($0.ownerHash) })
																							.filter({ poiVisibility[$0.hashValue] != nil })
		for poiPlane in visiblePrimitives {
			let parameters = poiVisibility[poiPlane.hashValue]! // Ensured by visiblePoiPlanes()
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

func buildPlaceMarkers(places: Set<GeoPlace>) -> ([ScaleVertex], [UInt32]) {
	let vertices = places.reduce([]) { (accumulator: [ScaleVertex], place: GeoPlace) in
		let size = 1.0 / Float(place.rank > 0 ? place.rank : 1)
		let v0 = ScaleVertex(0.0, 0.0, normalX: -size, normalY: -size)
		let v1 = ScaleVertex(0.0, 0.0, normalX: size, normalY: -size)
		let v2 = ScaleVertex(0.0, 0.0, normalX: size, normalY: size)
		let v3 = ScaleVertex(0.0, 0.0, normalX: -size, normalY: size)
		let verts = [v0, v1, v2, v3].map {
			ScaleVertex(place.location.x, place.location.y, normalX: $0.normalX, normalY: $0.normalY)
		}
		return accumulator + verts
	}
	
	let quadRange = 0..<UInt32(places.count)
	let indices = quadRange.reduce([]) { (accumulator: [UInt32], quadIndex: UInt32) in
		let quadIndices: [UInt32] = [0, 2, 1, 0, 3, 2]	// Build two triangles from the four quad vertices
		let vertexOffset = quadIndex * 4
		let offsetIndices = quadIndices.map { $0 + vertexOffset }
		return accumulator + offsetIndices
	}
	
	return (vertices, indices)
}

func sortPlacesIntoPoiPlanes<T: GeoIdentifiable>(_ places: Set<GeoPlace>, in container: T) -> [PoiPlane] {
	let rankedPlaces = bucketPlaceMarkers(places: places)
	return rankedPlaces.map { (rank, places) in
		let (vertices, indices) = buildPlaceMarkers(places: places)
		let primitive = IndexedRenderPrimitive<ScaleVertex>(vertices: vertices,
																						indices: indices,
																						color: rank.hashColor.tuple(),
																						ownerHash: container.geographyId.hashed,	// The hash of the owning region
																						debugName: "\(container.name) - poi plane @ \(rank)")
		let hashes = places.map { $0.hashValue }
		return PoiPlane(primitive: primitive, rank: rank, poiHashes: hashes)
	}
}

extension GeoPlaceContainer where Self : GeoIdentifiable {
	func poiRenderPlanes() -> [PoiPlane] {
		return sortPlacesIntoPoiPlanes(places, in: self);
	}
}
