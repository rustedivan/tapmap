//
//  LabelLayoutTests.swift
//  tapmapTests
//
//  Created by Ivan Milles on 2021-01-25.
//  Copyright © 2021 Wildbrain. All rights reserved.
//

import XCTest
import CoreGraphics.CGGeometry

func measureLabel(marker: LabelMarker) -> (w: Float, h: Float) {
	return (w: Float(marker.name.count), h: 8)
}

class LabelLayoutTests: XCTestCase {
	func testAddToEmptyLayout() {
		let layouter = LabelLayoutEngine(maxLabels: 5,
																		 space: Aabb(loX: 0, loY: 0, hiX: 320, hiY: 240),
																		 measure: measureLabel)
		layouter.labelMargin = 3.0
		let markers = [
			1 : LabelMarker(for: GeoPlace(location: Vertex(5, 5), name: "Marker 1", kind: .City, rank: 1)),
			2 : LabelMarker(for: GeoPlace(location: Vertex(5, 35), name: "Marker 2", kind: .City, rank: 1)),
		]
		
		let (layout, _) = layouter.layoutLabels(markers: markers) { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
		XCTAssertEqual(layout.count, 2)
	}
	
	func testAddToExistingLayout() {
		
	}
	
	func testStableInsertionOrdering() {
		
	}
	
	func testNewMarkerPrioritization() {
		
	}
	
	func testLabelLimit() {
		
	}
	
	func testLayoutWithAnchorSequence() {
		
	}
	
	func testLayoutRejectedLabel() {
		
	}
	
	func testEjectedLabel() {
		
	}
	
	func testRemoveFromLayout() {
		
	}
	
	func testInsertionHysteresis() {
		
	}
}
