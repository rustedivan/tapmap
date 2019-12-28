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
		let qIn = QuadTree(minX: -180.0, minY: -80.0, maxX: 180.0, maxY: 80.0)
		guard case .Empty(_) = qIn.root else {
			XCTFail("Empty tree's root is not empty")
			return
		}
		let qOut = quadInsert(hash: 7, region: Bounds(minX: -10.0, minY: -10.0, maxX: 10.0, maxY: 10.0), into: qIn.root)
		guard case let .Node(_, values, _, _, _, _) = qOut else {
			XCTFail("Inserted root was not a node")
			return
		}
		XCTAssertTrue(values.contains(7))
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
