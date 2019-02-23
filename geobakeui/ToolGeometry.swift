//
//  ToolGeometry.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-11-30.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift

// MARK: Structures
struct Vertex : Equatable, Hashable, PointForm {
	typealias Precision = Double
	var p: Vertex { return self }
	
	let x: Precision
	let y: Precision
	init(_ _x: Precision, _ _y: Precision) { x = _x; y = _y }
	
	var quantized : (Int64, Int64) {
		let quant: Precision = 1e-6
		return (Int64(floor(x / quant)), Int64(floor(y / quant)))
	}
	
	static func ==(lhs: Vertex, rhs: Vertex) -> Bool {
		return lhs.quantized == rhs.quantized
	}
	
	var hashValue : Int {
		return String("\(quantized)").hashValue
	}
}

struct Edge : Equatable, Hashable, PointForm {
	let v0: Vertex
	let v1: Vertex
	
	var p : Vertex { return v0 }
	
	init(_ _v0: Vertex, _ _v1: Vertex) {
		v0 = _v0
		v1 = _v1
	}
	
	static func ==(lhs: Edge, rhs: Edge) -> Bool {
		return (lhs.v0 == rhs.v0 && lhs.v1 == rhs.v1) || (lhs.v0 == rhs.v1 && lhs.v1 == rhs.v0)
	}
	
	var hashValue : Int {
		let orderedHashes = [v0.hashValue, v1.hashValue].sorted()
		return String("\(orderedHashes)").hashValue
	}
}

struct VertexRing {
	var vertices: [Vertex]
	var contour : [CVector3] {
		return vertices.map { CVector3(x: Float($0.x), y: Float($0.y), z: 0.0) }
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

struct Polygon {
	var exteriorRing: VertexRing
	var interiorRings: [VertexRing]
	
	func totalVertexCount() -> Int {
			return exteriorRing.vertices.count +
						 interiorRings.reduce(0) { $0 + $1.vertices.count }
	}
}

// MARK: Algorithms

func snapPointToEdge(p: Vertex, threshold: Double, edge: (a : Vertex, b : Vertex)) -> (Vertex, Double) {
	let a = edge.a
	let b = edge.b
	let ab = Vertex(b.x - a.x, b.y - a.y)
	let ap = Vertex(p.x - a.x, p.y - a.y)
	let segLenSqr = ab.x * ab.x + ab.y * ab.y
	let t = (ap.x * ab.x + ap.y * ab.y) / segLenSqr
	
	// If the closest point is within the segment...
	if t >= 0.0 && t <= 1.0 {
		// Find the closest point
		let q = Vertex(a.x + ab.x * t, a.y + ab.y * t)
		// Calculate distance to closest point on the line
		let pq = Vertex(p.x - q.x, p.y - q.y)
		let dSqr = pq.x * pq.x + pq.y * pq.y
		if dSqr < threshold * threshold {
			return (q, dSqr)
		}
	}
	
	return (p, Double.greatestFiniteMagnitude)
}

func tessellate(_ feature: ToolGeoFeature) -> GeoTessellation? {
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
			Vertex(Double($0.x), Double($0.y))
		}
		let indices = t.indices.map { UInt32($0) }
		let aabb = regionVertices.reduce(Aabb()) { aabb, v in
			let out = Aabb(loX: min(Float(v.x), aabb.minX),
										 loY: min(Float(v.y), aabb.minY),
										 hiX: max(Float(v.x), aabb.maxX),
										 hiY: max(Float(v.y), aabb.maxY))
			return out
		}
		
		let expandedVertices = indices.reduce([]) { (accumulator, index) -> [Vertex] in
			let indexedVertex = regionVertices[Int(index)]
			return accumulator + [indexedVertex]
		}
		
		return GeoTessellation(vertices: expandedVertices, aabb: aabb)
	} catch {
		return nil
	}
}
