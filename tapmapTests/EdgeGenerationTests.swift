//
//  EdgeGenerationTests.swift
//  tapmapTests
//
//  Created by Ivan Milles on 2019-07-22.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import XCTest

class EdgeGenerationTests: XCTestCase {

	func testShouldFattenEdge() {
		
	}
	
	func shouldIntersectEdges() {
		
	}
	
	func shouldHandleConvexCorners() {
		
	}
	
	func shouldHandleIncidentEdges() {
		
	}
	
	func shouldHandleConcaveCorners() {
		
	}
	
	func testShouldFattenEdge() {
		let edge = (v0: Vertex(10.0, 20.0), v1: Vertex(20.0, 10.0))
		let quad = fattenEdge(edge, width: 1.0)
		
		XCTAssertEqual(quad.in0, edge.v0)
		XCTAssertEqual(quad.in1, edge.v1)
		XCTAssertEqual(quad.out0.x, 10.7, accuracy: 0.1)
		XCTAssertEqual(quad.out0.y, 20.7, accuracy: 0.1)
		XCTAssertEqual(quad.out1.x, 20.7, accuracy: 0.1)
		XCTAssertEqual(quad.out1.y, 10.7, accuracy: 0.1)
	}
	
	func testShouldGenerateFatEdgeGeometry() {
		let v0 = Vertex(0.0, 10.0)
		let v1 = Vertex(10.0, 0.0)
		let v2 = Vertex(0.0, -10.0)
		let v3 = Vertex(-10.0, 0.0)
		
		let (vertices, indices) = generateOutlineGeometry(outline: [v0, v1, v2, v3], width: 5.0)
		XCTAssertEqual(vertices.count, 16)
		XCTAssertEqual(indices.count, 24)
		
		let quad1 = indices[0..<6]
		XCTAssertEqual(Array(quad1), [0, 1, 2, 2, 1, 3])
		
		let quad2 = indices[6..<12]
		XCTAssertEqual(Array(quad2), [4, 5, 6, 6, 5, 7])
		
		let quad3 = indices[12..<18]
		XCTAssertEqual(Array(quad3), [8, 9, 10, 10, 9, 11])
		
		let quad4 = indices[18..<24]
		XCTAssertEqual(Array(quad4), [12, 13, 14, 14, 13, 15])
	}
	
	func shouldMakeMiterJoin() {
		
	}
	
	func shouldBuildRenderPrimitive() {
		
	}
	
	func shouldCacheEdgePrimitives() {
		
	}
}
