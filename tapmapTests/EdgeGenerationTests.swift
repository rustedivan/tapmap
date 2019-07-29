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
		let rib = makeRib(v0, v1, width: 2.0)
		
		XCTAssertEqual(rib.inner.x, 9.3, accuracy: 0.1)
		XCTAssertEqual(rib.inner.y, 19.3, accuracy: 0.1)
		XCTAssertEqual(rib.outer.x, 10.7, accuracy: 0.1)
		XCTAssertEqual(rib.outer.y, 20.7, accuracy: 0.1)
	}
	
	func testShouldMiterCorner() {
		let v0 = Vertex( 0.0,  10.0)
		let v1 = Vertex(10.0, 10.0)
		let v2 = Vertex(10.0, -10.0)
		let mitered = makeMiterRib(v0, v1, v2, width: 1.0)
		
		XCTAssertEqual(mitered.inner.x, 9.5, accuracy: 0.1)
		XCTAssertEqual(mitered.inner.y, 9.5, accuracy: 0.1)
		XCTAssertEqual(mitered.outer.x, 10.5, accuracy: 0.1)
		XCTAssertEqual(mitered.outer.y, 10.5, accuracy: 0.1)
	}
	
	func testShouldGenerateFatEdgeGeometry() {
		let v0 = Vertex( 0.0,  10.0)
		let v1 = Vertex(10.0, 10.0)
		let v2 = Vertex(10.0, -10.0)

		let vertices = generateOutlineGeometry(outline: [v0, v1, v2], width: 5.0)
		XCTAssertEqual(vertices.count, 6)
		
		XCTAssertEqual(vertices[0].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(vertices[0].y,  7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[1].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(vertices[1].y, 12.5, accuracy: 0.1)
		
		XCTAssertEqual(vertices[2].x,  7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[2].y,  7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[3].x, 12.5, accuracy: 0.1)
		XCTAssertEqual(vertices[3].y, 12.5, accuracy: 0.1)
		
		XCTAssertEqual(vertices[4].x,   7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[4].y, -10.0, accuracy: 0.1)
		XCTAssertEqual(vertices[5].x,  12.5, accuracy: 0.1)
		XCTAssertEqual(vertices[5].y, -10.0, accuracy: 0.1)
	}
	
	func testShouldGenerateFatLoopGeometry() {
		let v0 = Vertex( 0.0,  10.0)
		let v1 = Vertex(10.0, 10.0)
		let v2 = Vertex(10.0, -10.0)
		
		let vertices = generateOutlineGeometry(outline: [v0, v1, v2], width: 5.0)
		XCTAssertEqual(vertices.count, 6)
		
		XCTAssertEqual(vertices[0].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(vertices[0].y,  7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[1].x,  0.0, accuracy: 0.1)
		XCTAssertEqual(vertices[1].y, 12.5, accuracy: 0.1)
		
		XCTAssertEqual(vertices[2].x,  7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[2].y,  7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[3].x, 12.5, accuracy: 0.1)
		XCTAssertEqual(vertices[3].y, 12.5, accuracy: 0.1)
		
		XCTAssertEqual(vertices[4].x,   7.5, accuracy: 0.1)
		XCTAssertEqual(vertices[4].y, -10.0, accuracy: 0.1)
		XCTAssertEqual(vertices[5].x,  12.5, accuracy: 0.1)
		XCTAssertEqual(vertices[5].y, -10.0, accuracy: 0.1)
	}

	func shouldCacheEdgePrimitives() {
		
	}
}
