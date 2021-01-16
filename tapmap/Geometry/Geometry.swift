//
//  Geometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry

struct GeometryCounters {
	static var aabbHitCount = 0
	static var triHitCount = 0
	
	static func begin() {
		GeometryCounters.aabbHitCount = 0
		GeometryCounters.triHitCount = 0
	}
	
	static func end() {
//		print("Performed \(GeometryCounters.aabbHitCount) box tests and \(GeometryCounters.triHitCount) triangle tests.")
	}
}

func boxContains(_ aabb: Aabb, _ p: Vertex) -> Bool {
	GeometryCounters.aabbHitCount += 1
	return (aabb.minX < p.x && p.x < aabb.maxX &&
					aabb.minY < p.y && p.y < aabb.maxY)
}

func boxIntersects(_ a: Aabb, _ b: Aabb) -> Bool {
	return !( a.minX >= b.maxX ||
						a.maxX <= b.minX ||
						a.minY >= b.maxY ||
						a.maxY <= b.minY)
}

func pickFromTessellations<T:GeoIdentifiable>(p: Vertex, candidates: Set<T>) -> RegionHash? {
	let streamer = GeometryStreamer.shared
	for candidate in candidates {
		let hash = candidate.geographyId.hashed
		guard let tessellation = streamer.tessellation(for: hash, atLod: streamer.actualLodLevel) else {
			continue
		}
		if triangleSoupHitTest(point: p, inVertices: tessellation.vertices, withIndices: tessellation.indices) {
			return hash
		}
	}
	return nil
}

// Assumes triangles is CCW GL_TRIANGLES mode (consecutive triplets form triangles)
func triangleSoupHitTest(point p: Vertex, inVertices vertices: [Vertex], withIndices indices: [UInt16]) -> Bool {
	for i in stride(from: 0, to: indices.count, by: 3) {
		GeometryCounters.triHitCount += 1
		
		// Pick up the corners of the triangle
		let i0 = Int(indices[i + 0])
		let i1 = Int(indices[i + 1])
		let i2 = Int(indices[i + 2])
		let x0 = vertices[i0].x, y0 = vertices[i0].y
		let x1 = vertices[i1].x, y1 = vertices[i1].y
		let x2 = vertices[i2].x, y2 = vertices[i2].y
		
		// Triangle hits are resolved using barycentric coordinates.
		// The point is expressed in barycentric coordinates, that is,
		// a linear combination of the triangle's points. The coefficients
		// (l1, l2, l3) of the linear combination must be positive and sum to 1.0.
		// Eq.1: (P = l1*v0 + l2*v1 + l3*v2; l1 + l2 + l3 = 1.0)
		// If the point P cannot be expressed by three positive coefficients,
		// it is outside the triangle.
		
		// Since l3 = 1 - l1 - l2, Eq.1 can be rearranged:
		// Eq.2: l1 * v0 + l2 * v1 + (1 - l1 - l2) * v2
		
		// ...and be expressed in vector notation:
		// Eq.3:
		// L:     T:							 r:
		// |l1| * |x0-x2  x1-x2| + (x2 - p.x) = 0
		// |l2|   |y0-y2  y1-y2| + (y2 - p.y) = 0
		
		// Solving for the L-vector by inverting the T matrix:
		// Eq.4:
		// L = inv(T) * r
		
		// With the barycentric coordinates in the L vector,
		// check if they are all positive and sum to 1.0 (l3 is implicit):
		// Eq5: inside = 0<=l[n]<=1 for all n=1..3
		
		// Calculate elements of matrix T
		let t11 = x0 - x2
		let t12 = x1 - x2
		let t21 = y0 - y2
		let t22 = y1 - y2
		
		// Calculate elements of vector r
		let r0 = Vertex.Precision(p.x) - x2
		let r1 = Vertex.Precision(p.y) - y2
		
		// Calculate determinant of T
		let det = (t11 * t22 - t12 * t21)
		
		// Invert 2x2 T, multiply by r, divide by determinant
		// to find L vector and the implicit l3.
		let l1 = ( t22 * r0 + -t12 * r1) / det
		let l2 = (-t21 * r0 +  t11 * r1) / det
		let l3 = 1.0 - l1 - l2
		
		// p is in t if all barycentric coordinates are in 0..1
		if l1 >= 0.0 && l1 <= 1.0 &&
			l2 >= 0.0 && l2 <= 1.0 &&
			l3 >= 0.0 && l3 <= 1.0 {
			return true
		}
	}
	return false
}
