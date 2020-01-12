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
		let viewRect = NSCoder.cgRect(for: "{{0, 0}, {640, 480}}")			// Full screen
		let imageRect = NSCoder.cgRect(for: "{{270, 190}, {100, 100}}") // Small square image in the middle
		let space = NSCoder.cgRect(for: "{{-180, -80}, {360, 160}}")		// Image represents world map
		
		let p = NSCoder.cgPoint(for: "{270, 190}")											// Top left corner of image
		let q = mapPoint(p, from: viewRect, to: imageRect, space: space)
		
		XCTAssertEqual(q.x, -180, accuracy: 1.0)
		XCTAssertEqual(q.y, -80, accuracy: 1.0)
	}
	
	func testTransformImageToViewSpace() {
// $ Test projectPoint instead
//		let viewRect = NSCoder.cgRect(for: "{{0, 0}, {640, 480}}")			 // Full screen
//		let imageRect = NSCoder.cgRect(for: "{{-180, -80}, {360, 160}}") // Map on the left half of screen
//		let space = NSCoder.cgRect(for: "{{0, 0}, {640, 480}}")					 // View fills screen
//
//		let p = NSCoder.cgPoint(for: "{-90, -40}")											 // Halfway west, halfway north
//		let q = mapPoint(p, from: imageRect, to: viewRect, space: space)
//
//		XCTAssertEqual(q.x, 160.0, accuracy: 1.0)
//		XCTAssertEqual(q.y, 120.0, accuracy: 1.0)
	}
	
//	func testTransfromScaledSpaces() {
//		let viewRect = NSCoder.cgRect(for: "{{0, 0}, {500, 400}}")
//		let imageRect = NSCoder.cgRect(for: "{{0, 0}, {360, 160}}")
//
//		let p = NSCoder.cgPoint(for: "{250, 200}")
//		let q = mapPoint(p, from: viewRect, to: imageRect, space: imageRect)
//
//		XCTAssertEqual(q.x, 180, accuracy: 1.0)
//		XCTAssertEqual(q.y, 80, accuracy: 1.0)
//	}
//
//	func testMapFromViewToWorld() {
//		let imageRect = NSCoder.cgRect(for: "{{100, 100}, {400, 100}}")
//		let worldRect = NSCoder.cgRect(for: "{{-180, -80}, {360, 160}}")
//
//		let p = NSCoder.cgPoint(for: "{150, 150}")
//		let q = mapPoint(p, from: imageRect, to: worldRect, space: imageRect)
//
//		XCTAssertEqual(q.x, -135.0, accuracy: 1.0)
//		XCTAssertEqual(q.y, 0.0, accuracy: 1.0)
//	}
}
