//
//  MapGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-06-19.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry
import GLKit

struct GeometryCounters {
	static var aabbHitCount = 0
	static var triHitCount = 0
	
	static func begin() {
		GeometryCounters.aabbHitCount = 0
		GeometryCounters.triHitCount = 0
	}
	
	static func end() {
		print("Performed \(GeometryCounters.aabbHitCount) box tests and \(GeometryCounters.triHitCount) triangle tests.")
	}
}


func mapPoint(_ p: CGPoint, from a: CGRect, to b: CGRect) -> CGPoint {
	let u = (b.width) * (p.x - a.minX) / (a.width) + b.minX
	let v = (b.height) * (p.y - a.minY) / (a.height) + b.minY
	return CGPoint(x: u, y: v)
}

func aabbHitTest(p: CGPoint, in region: GeoRegion) -> Bool{
	let aabb = region.geometry.aabb
	
	// $ Replace aabb with CGRect directly.
	let rect = CGRect(x: Double(aabb.minX), y: Double(aabb.minY), width: Double(aabb.maxX - aabb.minX), height: Double(aabb.maxY - aabb.minY))
	
	GeometryCounters.aabbHitCount += 1
	
	return rect.contains(p)
}

// Assumes triangles is CCW GL_TRIANGLES mode (consecutive triplets form triangles)
func triangleSoupHitTest(point p: CGPoint, inVertices vertices: [Vertex], inIndices indices: [UInt32]) -> Bool {
	for i in stride(from: 0, to: indices.count, by: 3) {
		GeometryCounters.triHitCount += 1
		
		// Pick up the corners of the triangle
		let i0 = Int(indices[i+0])
		let i1 = Int(indices[i+1])
		let i2 = Int(indices[i+2])
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
		let r0 = Float(p.x) - x2
		let r1 = Float(p.y) - y2
		
		// Calculate determinant of T
		let det = (t11 * t22 - t12 * t21)
		
		// Invert 2x2 T, multiply by r, divide by determinant
		// to find L vector and the implicit l3.
		let l1 = ( t22 * r0 + -t12 * r1) / det
		let l2 = (-t21 * r0 +  t11 * r1) / det
		let l3 = 1.0 - l1 - l2
		
		// p is in t if all barycentric coordinates are in 0..1
		if 0.0 <= l1 && l1 <= 1.0 &&
			 0.0 <= l2 && l2 <= 1.0 &&
			 0.0 <= l3 && l3 <= 1.0 {
			return true
		}
	}
	return false
}

func buildProjectionMatrix(viewSize: CGSize, mapSize: CGSize, centeredOn center: CGPoint, zoomedTo zoom: Float) -> GLKMatrix4 {
	let projectionMatrix = GLKMatrix4MakeOrtho(0.0, Float(mapSize.width),
																						 Float(mapSize.height), 0.0,
																						 0.1, 2.0)
	let lng = Float((center.x / viewSize.width) * mapSize.width)
	let lat = Float((center.y / viewSize.height) * mapSize.height)
	let lngOffset = Float(mapSize.width / 2.0)
	let latOffset = Float(mapSize.height / 2.0)
	
	// Compute the model view matrix for the object rendered with GLKit
	// (Z = -1.0 to position between the clipping planes)
	var modelViewMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, -1.0)
	
	// Matrix operations, applied in reverse order
	// 3: Move to scaled UIScrollView content offset
	modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, -lng, -lat, 0.0)
	// 2: Scale the data and flip the Y axis
	modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, zoom, -zoom, 1.0)
	// 1: Center the data
	modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, lngOffset, -latOffset, 0.0)
	
	return GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
}
