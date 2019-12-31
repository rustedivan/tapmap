//
//  QuadTreeTests.swift
//  tapmapTests
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import XCTest

class QuadTreeTests: XCTestCase {
	func testInsertInRootNode() {
		var q = QuadTree(minX: -180.0, minY: -80.0, maxX: 180.0, maxY: 80.0, maxDepth: 10)
		q.insert(value: 7,
			 			 region: Bounds(minX: -10.0, minY: -10.0, maxX: 10.0, maxY: 10.0))
		guard case let .Node(_, values, _, _, _, _) = q.root else {
			XCTFail("Inserted root was not a node")
			return
		}
		XCTAssertTrue(values.contains(7))
	}
	
	func testInsertAndSplit() {
		var q = QuadTree(minX: 0.0, minY: 0.0, maxX: 20.0, maxY: 20.0, maxDepth: 10)
		q.insert(value: 7,
						 region: Bounds(minX: 2.5, minY: 2.5, maxX: 7.5, maxY: 7.5))
		
		guard case let .Node(_, rootValues, tl, .Empty, .Empty, .Empty) = q.root else {
			XCTFail("Root had values outside top-left")
			return
		}
		XCTAssertTrue(rootValues.isEmpty, "Root should not have any values")
		
		guard case let .Node(_, tlValues, .Empty, .Empty, .Empty, .Empty) = tl else {
			XCTFail("Top-left cell was not a leaf node")
			return
		}
		XCTAssertEqual(tlValues, [7])
	}
	
	func testInsertWithoutSplit() {
		var q = QuadTree(minX: 0.0, minY: 0.0, maxX: 20.0, maxY: 20.0, maxDepth: 10)
		q.insert(value: 7,
						 region: Bounds(minX: 2.5, minY: 2.5, maxX: 7.5, maxY: 7.5))
		q.insert(value: 8,
						 region: Bounds(minX: 3.0, minY: 3.0, maxX: 7.0, maxY: 7.0))
		
		guard case let .Node(_, _, .Node(_, innerValues, .Empty, .Empty, .Empty, .Empty), .Empty, .Empty, .Empty) = q.root else {
			XCTFail("Tree structure is incorrect")
			return
		}
		XCTAssertEqual(innerValues, [7, 8])
	}
	
	func testInsertInAllQuadrants() {
		var q = QuadTree(minX: -10.0, minY: -10.0, maxX: 10.0, maxY: 10.0, maxDepth: 10)
		q.insert(value: 1,
						 region: Bounds(minX: -9.0, minY: -9.0, maxX: -1.0, maxY: -1.0))
		q.insert(value: 2,
						 region: Bounds(minX:  1.0, minY: -9.0, maxX:  9.0, maxY: -1.0))
		q.insert(value: 3,
						 region: Bounds(minX: -9.0, minY:  1.0, maxX: -1.0, maxY:  9.0))
		q.insert(value: 4,
						 region: Bounds(minX:  1.0, minY:  1.0, maxX:  9.0, maxY:  9.0))
		
		guard case let .Node(_, _, tl, tr, bl, br) = q.root else {
			XCTFail()
			return
		}
		
		if case let .Node(_, tlValues, _, _, _, _) = tl,
			 case let .Node(_, trValues, _, _, _, _) = tr,
			 case let .Node(_, blValues, _, _, _, _) = bl,
			 case let .Node(_, brValues, _, _, _, _) = br {
			XCTAssertEqual(tlValues, [1])
			XCTAssertEqual(trValues, [2])
			XCTAssertEqual(blValues, [3])
			XCTAssertEqual(brValues, [4])
			return
		} else {
			XCTFail()
		}
	}
	
	func testStopAtMaxDepth() {
		var q = QuadTree(minX: 0.0, minY: 0.0, maxX: 8.0, maxY: 8.0, maxDepth: 3)
		q.insert(value: 1,
						 region: Bounds(minX: 0.0, minY: 0.0, maxX: 0.1, maxY: 0.1))
		XCTAssertEqual(q.depth, 3)
	}
	
	
	func testSplitBounds() {
		let bounds: Bounds = (-50.0, -40.0, 50.0, 30.0)
		let splits = splitBounds(b: bounds)
		XCTAssertTrue(splits.tl == Bounds(-50.0, -40.0,  0.0, -5.0))
		XCTAssertTrue(splits.tr == Bounds(  0.0, -40.0, 50.0, -5.0))
		XCTAssertTrue(splits.bl == Bounds(-50.0,  -5.0,  0.0, 30.0))
		XCTAssertTrue(splits.br == Bounds(  0.0,  -5.0, 50.0, 30.0))
	}
}
