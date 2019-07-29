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
typealias FatEdge = (in0: Vertex, in1: Vertex, out0: Vertex, out1: Vertex)
func fattenEdge(_ edge: (v0: Vertex, v1: Vertex), width: Float) -> FatEdge {
	let d = (dx: edge.v1.x - edge.v0.x, dy: edge.v1.y - edge.v0.y)
	let m = sqrt(d.dx * d.dx + d.dy * d.dy)
	let normal = (dx: -d.dy / m, dy: d.dx / m)
	let offset0 = Vertex(edge.v0.x + normal.dx * width, edge.v0.y + normal.dy * width)
	let offset1 = Vertex(edge.v1.x + normal.dx * width, edge.v1.y + normal.dy * width)
	
	return FatEdge(edge.v0, edge.v1,
								 offset0, offset1)
}

func intersection(e0: (v0: Vertex, v1: Vertex), e1: (v0: Vertex, v1: Vertex)) -> Vertex? {
	return nil
}

func generateOutlineGeometry(outline: [Vertex], width: Float) -> (vertices: [Vertex], indices: [UInt32]) {
	var outVertices: [Vertex] = []
	var outIndices: [UInt32] = []
	
	var loopedOutline = outline
	loopedOutline.append(outline.first!)
	for i in 1..<loopedOutline.count {
		let v0 = loopedOutline[i - 1]
		let v1 = loopedOutline[i - 0]
		let fatEdge = fattenEdge((v0: v0, v1: v1), width: width)
		
		// Output inner edge, and then the outer edge. Make triangles as follows:
		//   2-----3
		//   |  \  |	triangles: 0-1-2 and 2-1-3
		//   0-----1
		let base = UInt32(i - 1) * 4	// Four vertices consumed by each loop
		outIndices.append(contentsOf: [base + 0, base + 1, base + 2])
		outIndices.append(contentsOf: [base + 2, base + 1, base + 3])
		outVertices.append(contentsOf: [fatEdge.in0, fatEdge.in1, fatEdge.out0, fatEdge.out1])
	}
	
	return (vertices: outVertices, indices: outIndices)
}
