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
						 region: Aabb(loX: -10.0, loY: -10.0, hiX: 10.0, hiY: 10.0))
		guard case let .Node(_, values, _, _, _, _) = q.root else {
			XCTFail("Inserted root was not a node")
			return
		}
		XCTAssertTrue(values.contains(7))
	}
	
	func testInsertAndSplit() {
		var q = QuadTree(minX: 0.0, minY: 0.0, maxX: 20.0, maxY: 20.0, maxDepth: 10)
		q.insert(value: 7,
						 region: Aabb(loX: 2.5, loY: 2.5, hiX: 7.5, hiY: 7.5))
		
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
						 region: Aabb(loX: 2.5, loY: 2.5, hiX: 7.5, hiY: 7.5))
		q.insert(value: 8,
						 region: Aabb(loX: 3.0, loY: 3.0, hiX: 7.0, hiY: 7.0))
		
		guard case let .Node(_, _, .Node(_, innerValues, .Empty, .Empty, .Empty, .Empty), .Empty, .Empty, .Empty) = q.root else {
			XCTFail("Tree structure is incorrect")
			return
		}
		XCTAssertEqual(innerValues, [7, 8])
	}
	
	func testInsertInAllQuadrants() {
		var q = QuadTree(minX: -10.0, minY: -10.0, maxX: 10.0, maxY: 10.0, maxDepth: 10)
		q.insert(value: 1,
						 region: Aabb(loX: -9.0, loY: -9.0, hiX: -1.0, hiY: -1.0))
		q.insert(value: 2,
						 region: Aabb(loX:  1.0, loY: -9.0, hiX:  9.0, hiY: -1.0))
		q.insert(value: 3,
						 region: Aabb(loX: -9.0, loY:  1.0, hiX: -1.0, hiY:  9.0))
		q.insert(value: 4,
						 region: Aabb(loX:  1.0, loY:  1.0, hiX:  9.0, hiY:  9.0))
		
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
						 region: Aabb(loX: 0.0, loY: 0.0, hiX: 0.1, hiY: 0.1))
		XCTAssertEqual(q.depth, 3)
	}
	
	
	func testSplitAabb() {
		let bounds = Aabb(loX: -50.0, loY: -40.0, hiX: 50.0, hiY: 30.0)
		let splits = splitBounds(b: bounds)
		XCTAssertTrue(splits.tl == Aabb(loX: -50.0, loY: -40.0,  hiX: 0.0, hiY: -5.0))
		XCTAssertTrue(splits.tr == Aabb(  loX: 0.0, loY: -40.0, hiX: 50.0, hiY: -5.0))
		XCTAssertTrue(splits.bl == Aabb(loX: -50.0,  loY: -5.0,  hiX: 0.0, hiY: 30.0))
		XCTAssertTrue(splits.br == Aabb(  loX: 0.0,  loY: -5.0, hiX: 50.0, hiY: 30.0))
	}

	func testRemoveValue() {
		var q = QuadTree(minX: 0.0, minY: 0.0, maxX: 20.0, maxY: 20.0, maxDepth: 10)
		q.insert(value: 7,
						 region: Aabb(loX: 2.5, loY: 2.5, hiX: 7.5, hiY: 7.5))
		q.insert(value: 8,
						 region: Aabb(loX: 3.0, loY: 3.0, hiX: 7.0, hiY: 7.0))
		q.insert(value: 9,
						 region: Aabb(loX: 15.0, loY: 12.0, hiX: 16.0, hiY: 14.0))
		
		q.remove(value: 8)
		let values = q.query(box: Aabb(loX: 0.0, loY: 0.0, hiX: 20.0, hiY: 20.0))
		XCTAssertTrue(values.contains(7))
		XCTAssertFalse(values.contains(8))
		XCTAssertTrue(values.contains(9))
	}
}
