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
		let v0 = Vertex(10.0, 20.0)
		let v1 = Vertex(20.0, 10.0)
		let rib = makeRib(v0, v1)
		
		let inner = Vertex(rib.p.x + rib.miterIn.x, rib.p.y + rib.miterIn.y)
		let outer = Vertex(rib.p.x + rib.miterOut.x, rib.p.y + rib.miterOut.y)
		XCTAssertEqual(inner.x, 9.3, accuracy: 0.1)
		XCTAssertEqual(inner.y, 19.3, accuracy: 0.1)
		XCTAssertEqual(outer.x, 10.7, accuracy: 0.1)
		XCTAssertEqual(outer.y, 20.7, accuracy: 0.1)
	}
	
	func testShouldMiterCorner() {
		let v0 = Vertex( 0.0,  10.0)
		let v1 = Vertex(10.0, 10.0)
		let v2 = Vertex(10.0, -10.0)
		let rib = makeMiterRib(v0, v1, v2, 1.0, 1.0)
		
		let inner = Vertex(rib.p.x + rib.miterIn.x, rib.p.y + rib.miterIn.y)
		let outer = Vertex(rib.p.x + rib.miterOut.x, rib.p.y + rib.miterOut.y)
		XCTAssertEqual(inner.x, 9.0, accuracy: 0.1)
		XCTAssertEqual(inner.y, 9.0, accuracy: 0.1)
		XCTAssertEqual(outer.x, 11.0, accuracy: 0.1)
		XCTAssertEqual(outer.y, 11.0, accuracy: 0.1)
	}
	
	func testShouldGenerateFatEdgeGeometry() {
		let v0 = Vertex( 0.0,  10.0)
		let v1 = Vertex(10.0, 10.0)
		let v2 = Vertex(10.0, -10.0)

		let vertices = generateOutlineGeometry(outline: [v0, v1, v2])
		XCTAssertEqual(vertices.count, 6)
		
		let width: Vertex.Precision = 2.5
		let expandedVertices = vertices.map {
			Vertex($0.x + $0.normalX * width, $0.y + $0.normalY * width)
		}
		
		XCTAssertEqual(expandedVertices[0].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[0].y,  7.5, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[1].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[1].y, 12.5, accuracy: 0.1)
		
		XCTAssertEqual(expandedVertices[2].x,  8.75, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[2].y,  8.75, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[3].x, 11.25, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[3].y, 11.25, accuracy: 0.1)
		
		XCTAssertEqual(expandedVertices[4].x,   7.5, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[4].y, -10.0, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[5].x,  12.5, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[5].y, -10.0, accuracy: 0.1)
	}
	
	func testShouldGenerateFatLoopGeometry() {
		let v0 = Vertex( 0.0,  10.0)
		let v1 = Vertex(10.0, 10.0)
		let v2 = Vertex(10.0, -10.0)
		
		let vertices = generateOutlineGeometry(outline: [v0, v1, v2])
		XCTAssertEqual(vertices.count, 6)
		
		let width: Vertex.Precision = 2.5
		let expandedVertices = vertices.map {
			Vertex($0.x + $0.normalX * width, $0.y + $0.normalY * width)
		}
		
		XCTAssertEqual(expandedVertices[0].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[0].y,  7.5, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[1].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[1].y, 12.5, accuracy: 0.1)
		
		XCTAssertEqual(expandedVertices[2].x,  8.75, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[2].y,  8.75, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[3].x, 11.25, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[3].y, 11.25, accuracy: 0.1)
		
		XCTAssertEqual(expandedVertices[4].x,   7.5, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[4].y, -10.0, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[5].x,  12.5, accuracy: 0.1)
		XCTAssertEqual(expandedVertices[5].y, -10.0, accuracy: 0.1)
	}

	func shouldCacheEdgePrimitives() {
		
	}
}
