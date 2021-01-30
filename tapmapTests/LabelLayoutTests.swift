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

func prepareForAsserts(_ layout: LabelLayout) -> [LabelPlacement] {
	return Array(layout.values).sorted { $0.debugName < $1.debugName }
}

class LabelLayoutTests: XCTestCase {
	var layouter: LabelLayoutEngine!
	override func setUp() {
		layouter = LabelLayoutEngine(maxLabels: 5,
																		 space: Aabb(loX: 0, loY: 0, hiX: 320, hiY: 240),
																		 measure: measureLabel)
		layouter.labelMargin = 3.0
		layouter.labelDistance = 2
	}
	func testAddToEmptyLayout() {
		let markers = [
			1 : LabelMarker(for: GeoPlace(location: Vertex(5, 5), name: "Marker #1", kind: .City, rank: 1)),
			2 : LabelMarker(for: GeoPlace(location: Vertex(5, 35), name: "Marker #2", kind: .City, rank: 2)),
		]
		
		let (layout, _) = layouter.layoutLabels(markers: markers) { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
		let layoutedMarkers = prepareForAsserts(layout)
		XCTAssertEqual(layoutedMarkers.count, 2)
		XCTAssertEqual(layoutedMarkers[0].debugName, "Marker #1")
		XCTAssertEqual(layoutedMarkers[1].debugName, "Marker #2")
		
		XCTAssertEqual(layoutedMarkers[0].anchor, .NE)
		XCTAssertEqual(layoutedMarkers[0].aabb, Aabb(loX: 7.0, loY: -5.0, hiX: 16.0, hiY: 3.0))
		
		XCTAssertEqual(layoutedMarkers[1].anchor, .NE)
		XCTAssertEqual(layoutedMarkers[1].aabb, Aabb(loX: 7.0, loY: 25.0, hiX: 16.0, hiY: 33.0))
	}
	
	func testAddToExistingLayout() {
		
	}
	
	func testStableInsertionOrdering() {
		
	}
	
	func testAnchorWalking() {
		
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
