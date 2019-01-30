//
//  ToolGeometry.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-11-30.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift

struct GeoPolygonRing {
	var vertices: [Vertex]
	var contour : [CVector3] {
		return vertices.map { CVector3(x: $0.x, y: $0.y, z: 0.0) }
	}
	
	init(vertices inVerts: [Vertex]) {
		vertices = inVerts
		if vertices.first == vertices.last {
			vertices.removeLast()
		}
	}
	
	init(edges: [Edge]) {
		self.init(vertices: edges.map { $0.v0 })
	}
}

struct GeoPolygon {
	var exteriorRing: GeoPolygonRing
	var interiorRings: [GeoPolygonRing]
	
	func totalVertexCount() -> Int {
			return exteriorRing.vertices.count +
						 interiorRings.reduce(0) { $0 + $1.vertices.count }
	}
}

struct GeoFeature : Equatable, Hashable {
	enum Level {
		case Continent
		case Country
		case Region
	}
	
	let level: Level
	let polygons: [GeoPolygon]
	let stringProperties: [String : String]
	let valueProperties: [String : Double]
	
	var name : String {
		return stringProperties["name"] ?? stringProperties["NAME"] ?? "Unnamed"
	}
	
	var admin : String {
		return stringProperties["adm0_a3"] ?? stringProperties["ADM0_A3"] ?? "Unnamed"
	}
	
	var continent : String {
		return stringProperties["continent"] ?? stringProperties["CONTINENT"] ?? "Unnamed"
	}
	
	func totalVertexCount() -> Int {
		return polygons.reduce(0) { $0 + $1.totalVertexCount() }
	}
	
	public static func == (lhs: GeoFeature, rhs: GeoFeature) -> Bool {
		return lhs.level == rhs.level && lhs.name == rhs.name && lhs.admin == rhs.admin
	}
	
	public var hashValue: Int {
		return level.hashValue ^ name.hashValue ^ admin.hashValue
	}
}

struct GeoFeatureCollection {
	let features: Set<GeoFeature>
	
	func totalVertexCount() -> Int {
		return features.reduce(0) { $0 + $1.totalVertexCount() }
	}
}

func snapPointToEdge(p: Vertex, threshold: Float, edge: (a : Vertex, b : Vertex)) -> (Vertex, Float) {
	let a = edge.a
	let b = edge.b
	let ab = Vertex(x: b.x - a.x, y: b.y - a.y)
	let ap = Vertex(x: p.x - a.x, y: p.y - a.y)
	let segLenSqr = ab.x * ab.x + ab.y * ab.y
	let t = (ap.x * ab.x + ap.y * ab.y) / segLenSqr
	
	// If the closest point is within the segment...
	if t >= 0.0 && t <= 1.0 {
		// Find the closest point
		let q = Vertex(x: a.x + ab.x * t, y: a.y + ab.y * t)
		// Calculate distance to closest point on the line
		let pq = Vertex(x: p.x - q.x, y: p.y - q.y)
		let dSqr = pq.x * pq.x + pq.y * pq.y
		if dSqr < threshold * threshold {
			return (q, dSqr)
		}
	}
	
	return (p, Float.greatestFiniteMagnitude)
}

func tessellate(_ feature: GeoFeature) -> GeoTessellation? {
	guard let tess = TessC() else {
		print("Could not init TessC")
		return nil
	}
	
	for polygon in feature.polygons {
		let exterior = polygon.exteriorRing.contour
		tess.addContour(exterior)
		let interiorContours = polygon.interiorRings.map{ $0.contour }
		for interior in interiorContours {
			tess.addContour(interior)
		}
	}
	
	do {
		let t = try tess.tessellate(windingRule: .evenOdd,
																elementType: ElementType.polygons,
																polySize: 3,
																vertexSize: .vertex2)
		let regionVertices = t.vertices.map {
			Vertex(x: $0.x, y: $0.y)
		}
		let indices = t.indices.map { UInt32($0) }
		let aabb = regionVertices.reduce(Aabb()) { aabb, v in
			let out = Aabb(loX: min(v.x, aabb.minX),
										 loY: min(v.y, aabb.minY),
										 hiX: max(v.x, aabb.maxX),
										 hiY: max(v.y, aabb.maxY))
			return out
		}
		
		return GeoTessellation(vertices: regionVertices, indices: indices, aabb: aabb)
	} catch {
		return nil
	}
}
