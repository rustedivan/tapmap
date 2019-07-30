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

func aabbHitTest(p: CGPoint, aabb: Aabb) -> Bool {
	// $ Replace aabb with CGRect directly.
	let rect = CGRect(x: Double(aabb.minX), y: Double(aabb.minY), width: Double(aabb.maxX - aabb.minX), height: Double(aabb.maxY - aabb.minY))
	
	GeometryCounters.aabbHitCount += 1
	
	return rect.contains(p)
}

func pickFromTessellations<T:GeoTessellated>(p: CGPoint, candidates: Set<T>) -> T? {
	for tessellation in candidates {
		if triangleSoupHitTest(point: p,
													 inVertices: tessellation.geometry.vertices) {
			return tessellation
		}
	}
	return nil
}

// Assumes triangles is CCW GL_TRIANGLES mode (consecutive triplets form triangles)
func triangleSoupHitTest(point p: CGPoint, inVertices vertices: [Vertex]) -> Bool {
	for i in stride(from: 0, to: vertices.count, by: 3) {
		GeometryCounters.triHitCount += 1
		
		// Pick up the corners of the triangle
		let x0 = vertices[i + 0].x, y0 = vertices[i + 0].y
		let x1 = vertices[i + 1].x, y1 = vertices[i + 1].y
		let x2 = vertices[i + 2].x, y2 = vertices[i + 2].y
		
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

// MARK: Outline generation
func vectorAdd(_ v0: Vertex, _ v1: Vertex) -> Vertex {
	return Vertex(v1.x + v0.x, v1.y + v0.y)
}

func vectorSub(_ v0: Vertex, _ v1: Vertex) -> Vertex {
	return Vertex(v0.x - v1.x, v0.y - v1.y)
}

func normalize(_ v: Vertex) -> Vertex {
	let m = sqrt(v.x * v.x + v.y * v.y)
	return Vertex(v.x / m, v.y / m)
}

func normal(_ v: Vertex) -> Vertex {
	return normalize(Vertex(-v.y, v.x))
}

func dotProduct(_ v0: Vertex, _ v1: Vertex) -> Vertex.Precision {
	return v0.x * v1.x + v0.y * v1.y
}

func anchorTangent(v0: Vertex, v1: Vertex, v2: Vertex) -> Vertex {
	return normalize(vectorAdd(normalize(vectorSub(v1, v0)), normalize(vectorSub(v2, v1))))
}

typealias Rib = (inner: Vertex, outer: Vertex)
func makeRib(_ v0: Vertex, _ v1: Vertex, width: Vertex.Precision) -> Rib {
	let edge = normalize(vectorSub(v1, v0))
	let n = normal(edge)
	let halfW = width / 2.0
	let inner = Vertex(v0.x - n.x * halfW, v0.y - n.y * halfW)
	let outer = Vertex(v0.x + n.x * halfW, v0.y + n.y * halfW)
	
	return Rib(inner, outer)
}

func makeMiterRib(_ v0: Vertex, _ v1: Vertex, _ v2: Vertex, width: Vertex.Precision) -> Rib {
	let incomingNormal = normal(vectorSub(v1, v0))
	let tangent = anchorTangent(v0: v0, v1: v1, v2: v2)
	let miter = Vertex(-tangent.y, tangent.x)
	var miterLength = width / dotProduct(miter, incomingNormal) / 2.0
	miterLength = min(miterLength, 2.0 * width)
	
	let inner = Vertex(v1.x - miter.x * miterLength, v1.y - miter.y * miterLength)
	let outer = Vertex(v1.x + miter.x * miterLength, v1.y + miter.y * miterLength)
	
	return Rib(inner, outer)
}

func generateOutlineGeometry(outline: [Vertex], width: Vertex.Precision) -> [Vertex] {
	guard outline.count >= 2 else { return [] }

	let firstRib = makeRib(outline[0], outline[1], width: width)
	var miterRibs: [Rib] = []
	for i in 1..<outline.count - 1 {
		let miterRib = makeMiterRib(outline[i - 1], outline[i], outline[i + 1], width: width)
		miterRibs.append(miterRib)
	}
	
	var lastRib = makeRib(outline[outline.count - 1], outline[outline.count - 2], width: width)
	swap(&lastRib.inner, &lastRib.outer)	// lastRib will have inverted normal, so flip it back
	
	let ribs = [firstRib] + miterRibs + [lastRib]
	
	let outVertices = ribs.reduce([]) { (acc, cur) in
		return acc + [cur.inner, cur.outer]
	}
	return outVertices
}

func generateClosedOutlineGeometry(outline: [Vertex], width: Vertex.Precision) -> [Vertex] {
	guard outline.count >= 3 else { return [] }
	
	let firstRib = makeMiterRib(outline.last!, outline.first!, outline[1], width: width)
	var miterRibs: [Rib] = []
	for i in 1..<outline.count - 1 {
		let miterRib = makeMiterRib(outline[i - 1], outline[i], outline[i + 1], width: width)
		miterRibs.append(miterRib)
	}
	
	let endRib = makeMiterRib(outline[outline.count - 2], outline.last!, outline.first!, width: width)
	let closeRib = makeMiterRib(outline[outline.count - 1], outline.first!, outline[1], width: width)
	
	let ribs = [firstRib] + miterRibs + [endRib, closeRib]
	
	let outVertices = ribs.reduce([]) { (acc, cur) in
		return acc + [cur.inner, cur.outer]
	}
	return outVertices
}

