//
//  GeometryTests.swift
//  tapmapTests
//
//  Created by Ivan Milles on 2018-06-16.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import XCTest
import GLKit

class GeometryTests: XCTestCase {
	func testTransformViewToImageSpace() {
		let viewRect = CGRectFromString("{{0, 0}, {667, 358}}")
		let imageRect = CGRectFromString("{{-180, -80}, {360, 160}}")
		
		let p = CGPointFromString("{150, 40}")
		let q = mapPoint(p, from: viewRect, to: imageRect)
		
		XCTAssertEqual(q.x, -100.0, accuracy: 1.0)
		XCTAssertEqual(q.y, -62.0, accuracy: 1.0)
	}
	
	func testTransformImageToViewSpace() {
		let viewRect = CGRectFromString("{{0, 0}, {667, 358}}")
		let imageRect = CGRectFromString("{{-180, -80}, {360, 160}}")
		
		let p = CGPointFromString("{-90, -40}")
		let q = mapPoint(p, from: imageRect, to: viewRect)
		
		XCTAssertEqual(q.x, 166.0, accuracy: 1.0)
		XCTAssertEqual(q.y, 90.0, accuracy: 1.0)
	}
	
	func testTransfromScaledSpaces() {
		let viewRect = CGRectFromString("{{0, 0}, {500, 400}}")
		let imageRect = CGRectFromString("{{0, 0}, {360, 160}}")
		
		let p = CGPointFromString("{250, 200}")
		let q = mapPoint(p, from: viewRect, to: imageRect)
		
		XCTAssertEqual(q.x, 180, accuracy: 1.0)
		XCTAssertEqual(q.y, 80, accuracy: 1.0)
	}
	
	func testMapFromViewToWorld() {
		let imageRect = CGRectFromString("{{100, 100}, {400, 100}}")
		let worldRect = CGRectFromString("{{-180, -80}, {360, 160}}")
		
		let p = CGPointFromString("{150, 150}")
		let q = mapPoint(p, from: imageRect, to: worldRect)
		
		XCTAssertEqual(q.x, -135.0, accuracy: 1.0)
		XCTAssertEqual(q.y, 0.0, accuracy: 1.0)
	}
}
