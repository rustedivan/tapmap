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
struct Vertex : Equatable, Hashable {
	typealias Precision = Double
	
	let x: Precision
	let y: Precision
	
	init(_ _x: Precision, _ _y: Precision) { x = _x; y = _y; }
	
	var quantized : (Int64, Int64) {
		let quant: Precision = 1e-3
		return (Int64(floor(x / quant)), Int64(floor(y / quant)))
	}
	
	static func ==(lhs: Vertex, rhs: Vertex) -> Bool {
		return lhs.quantized == rhs.quantized
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(quantized.0)
		hasher.combine(quantized.1)
	}
}

struct Edge : Equatable, Hashable {
	let v0: Vertex
	let v1: Vertex
	
	init(_ _v0: Vertex, _ _v1: Vertex) {
		v0 = _v0
		v1 = _v1
	}
	
	static func ==(lhs: Edge, rhs: Edge) -> Bool {
		return (lhs.v0 == rhs.v0 && lhs.v1 == rhs.v1) || (lhs.v0 == rhs.v1 && lhs.v1 == rhs.v0)
	}
	
	func hash(into hasher: inout Hasher) {
		let orderedHashes = [v0.hashValue, v1.hashValue].sorted()
		hasher.combine(orderedHashes)
	}
}

struct VertexRing : Codable {
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

struct EdgeIndices : Hashable {
	let lo, hi: Int
	init(_ i0: UInt32, _ i1: UInt32) {
		lo = Int(min(i0, i1))
		hi = Int(max(i0, i1))
	}
}

func tessellate(_ feature: ToolGeoFeature) -> GeoTessellation? {
	guard let tess = TessC() else {
		print("Could not init TessC")
		return nil
	}
	
	var contourEdges: [Edge] = []
	for polygon in feature.polygons {
		let exterior = polygon.exteriorRing.contour
		tess.addContour(exterior)
		let interiorContours = polygon.interiorRings.map{ $0.contour }
		for interior in interiorContours {
			tess.addContour(interior)
		}
		
		for i in 0..<polygon.exteriorRing.vertices.count {
			contourEdges.append(Edge(polygon.exteriorRing.vertices[i],
															 polygon.exteriorRing.vertices[(i + 1) % polygon.exteriorRing.vertices.count]))
		}
	}
	
	let t: (vertices: [CVector3], indices: [Int])
	do {
		t = try tess.tessellate(windingRule: .evenOdd,
														elementType: ElementType.polygons,
														polySize: 3,
														vertexSize: .vertex2)
	} catch {
		return nil
	}

	var aabb = Aabb()
	var midpoint: (Vertex.Precision, Vertex.Precision) = (0.0, 0.0)
	let regionVertices = t.vertices.map { (v: CVector3) -> Vertex in
		// Calculate the aabb while we're passing through
		aabb = Aabb(loX: min(Vertex.Precision(v.x), aabb.minX),
								loY: min(Vertex.Precision(v.y), aabb.minY),
								hiX: max(Vertex.Precision(v.x), aabb.maxX),
								hiY: max(Vertex.Precision(v.y), aabb.maxY))
		midpoint.0 += Vertex.Precision(v.x)
		midpoint.1 += Vertex.Precision(v.y)
		return Vertex(Vertex.Precision(v.x), Vertex.Precision(v.y))
	}
	midpoint.0 /= Double(regionVertices.count)
	midpoint.1 /= Double(regionVertices.count)
	
	let indices = t.indices.map { UInt32($0) }
	
	var flattenedVertices: [Vertex] = []
	for i in stride(from: 0, to: indices.count, by: 3) {
		let i0 = indices[i + 0]
		let i1 = indices[i + 1]
		let i2 = indices[i + 2]
		
		// Expand the index-based vertices into straight arrays
		let v0 = regionVertices[Int(i0)]
		let v1 = regionVertices[Int(i1)]
		let v2 = regionVertices[Int(i2)]
		
		flattenedVertices.append(contentsOf: [v0, v1, v2])
	}

	return GeoTessellation(vertices: flattenedVertices, contours: feature.polygons.map { $0.exteriorRing }, aabb: aabb, midpoint: Vertex(midpoint.0, midpoint.1))
}
