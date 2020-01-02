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
		
		guard case let .Node(_, rootValues, .Empty, .Empty, bl, .Empty) = q.root else {
			XCTFail("Root had values outside bottom-left")
			return
		}
		XCTAssertTrue(rootValues.isEmpty, "Root should not have any values")
		
		guard case let .Node(_, blValues, .Empty, .Empty, .Empty, .Empty) = bl else {
			XCTFail("Bottom-left cell was not a leaf node")
			return
		}
		XCTAssertEqual(blValues, [7])
	}
	
	func testInsertWithoutSplit() {
		var q = QuadTree(minX: 0.0, minY: 0.0, maxX: 20.0, maxY: 20.0, maxDepth: 10)
		q.insert(value: 7,
						 region: Aabb(loX: 2.5, loY: 12.5, hiX: 7.5, hiY: 17.5))
		q.insert(value: 8,
						 region: Aabb(loX: 3.0, loY: 13.0, hiX: 7.0, hiY: 17.0))
		
		guard case let .Node(_, _, .Node(_, innerValues, .Empty, .Empty, .Empty, .Empty), .Empty, .Empty, .Empty) = q.root else {
			XCTFail("Tree structure is incorrect")
			return
		}
		XCTAssertEqual(innerValues, [7, 8])
	}
	
	func testInsertInAllQuadrants() {
		var q = QuadTree(minX: -10.0, minY: -10.0, maxX: 10.0, maxY: 10.0, maxDepth: 10)
		q.insert(value: 1,
						 region: Aabb(loX: -9.0, loY: 1.0, hiX: -1.0, hiY: 9.0))
		q.insert(value: 2,
						 region: Aabb(loX:  1.0, loY: 1.0, hiX:  9.0, hiY: 9.0))
		q.insert(value: 3,
						 region: Aabb(loX: -9.0, loY: -9.0, hiX: -1.0, hiY: -1.0))
		q.insert(value: 4,
						 region: Aabb(loX:  1.0, loY: -9.0, hiX:  9.0, hiY: -1.0))
		
		let tlValues = q.query(search: Aabb(loX: -10.0, loY:   0.0, hiX:  0.0, hiY: 10.0))
		let trValues = q.query(search: Aabb(loX: 0.0,   loY:   0.0, hiX: 10.0, hiY: 10.0))
		let blValues = q.query(search: Aabb(loX: -10.0, loY: -10.0, hiX:  0.0, hiY:  0.0))
		let brValues = q.query(search: Aabb(loX: 0.0,   loY: -10.0, hiX: 10.0, hiY:  0.0))
		let alValues = q.query(search: Aabb(loX: -10.0, loY: -10.0, hiX:  0.0, hiY: 10.0))
		let arValues = q.query(search: Aabb(loX: 0.0,   loY: -10.0, hiX: 10.0, hiY: 10.0))
		let atValues = q.query(search: Aabb(loX: -10.0, loY:   0.0, hiX: 10.0, hiY: 10.0))
		let abValues = q.query(search: Aabb(loX: -10.0, loY: -10.0, hiX: 10.0, hiY:  0.0))
		
		XCTAssertEqual(tlValues, Set([1]))
		XCTAssertEqual(trValues, Set([2]))
		XCTAssertEqual(blValues, Set([3]))
		XCTAssertEqual(brValues, Set([4]))
		XCTAssertEqual(alValues, Set([1, 3]))
		XCTAssertEqual(arValues, Set([2, 4]))
		XCTAssertEqual(atValues, Set([1, 2]))
		XCTAssertEqual(abValues, Set([3, 4]))
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
		XCTAssertTrue(splits.tl == Aabb(loX: -50.0, loY:  -5.0, hiX:  0.0, hiY: 30.0))
		XCTAssertTrue(splits.tr == Aabb(loX:   0.0, loY:  -5.0, hiX: 50.0, hiY: 30.0))
		XCTAssertTrue(splits.bl == Aabb(loX: -50.0, loY: -40.0, hiX:  0.0, hiY: -5.0))
		XCTAssertTrue(splits.br == Aabb(loX:   0.0, loY: -40.0, hiX: 50.0, hiY: -5.0))
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
		let values = q.query(search: Aabb(loX: 0.0, loY: 0.0, hiX: 20.0, hiY: 20.0))
		XCTAssertTrue(values.contains(7))
		XCTAssertFalse(values.contains(8))
		XCTAssertTrue(values.contains(9))
	}
}
