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

func nullProjection(v: Vertex) -> CGPoint {
	return CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
}

func offsetProjection(v: Vertex) -> CGPoint {
	return CGPoint(x: CGFloat(v.x + 4.0), y: CGFloat(v.y - 5.0))
}

func zoomProjection(v: Vertex) -> CGPoint {
	return CGPoint(x: CGFloat(v.x * 0.5), y: CGFloat(v.y * 0.5))
}


func makeMarkers(_ places: [GeoPlace]) -> [Int : LabelMarker] {
	return Dictionary(uniqueKeysWithValues: places.map { ($0.hashValue, LabelMarker(for: $0)) })
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
		layouter.labelDistance = 2.0
	}
	
	func testAddToEmptyLayout() {
		let markers = makeMarkers([
			GeoPlace(location: Vertex(5, 5), name: "Marker #1", kind: .City, rank: 1),
			GeoPlace(location: Vertex(5, 35), name: "Marker #2", kind: .City, rank: 2)
		])
		
		let (layout, _) = layouter.layoutLabels(markers: markers, projection: nullProjection)
		let ls = prepareForAsserts(layout)
		XCTAssertEqual(ls.count, 2)
		XCTAssertEqual(ls[0].debugName, "Marker #1")
		XCTAssertEqual(ls[1].debugName, "Marker #2")
		
		XCTAssertEqual(ls[0].anchor, .NE)
		XCTAssertEqual(ls[0].aabb, Aabb(loX: 7.0, loY: -5.0, hiX: 16.0, hiY: 3.0))
		
		XCTAssertEqual(ls[1].anchor, .NE)
		XCTAssertEqual(ls[1].aabb, Aabb(loX: 7.0, loY: 25.0, hiX: 16.0, hiY: 33.0))
	}
	
	func testAddToExistingLayout() {
		let previousMarkers = makeMarkers([
			GeoPlace(location: Vertex(5, 5), name: "Marker #1", kind: .City, rank: 1),
			GeoPlace(location: Vertex(5, 35), name: "Marker #2", kind: .City, rank: 2)
		])
		_ = layouter.layoutLabels(markers: previousMarkers, projection: nullProjection)
		
		let incomingMarkers = makeMarkers([
			GeoPlace(location: Vertex(20, 20), name: "Marker #3", kind: .Town, rank: 4),
			GeoPlace(location: Vertex(20, 40), name: "Marker #4", kind: .Town, rank: 5)
		])
		
		let fullSet = previousMarkers.merging(incomingMarkers, uniquingKeysWith: { _,_ in fatalError() })
		let (layout, _) = layouter.layoutLabels(markers: fullSet, projection: nullProjection)
		let ls = prepareForAsserts(layout)
		
		XCTAssertEqual(ls.count, 4)
		XCTAssertEqual(ls[0].debugName, "Marker #1")
		XCTAssertEqual(ls[1].debugName, "Marker #2")
		XCTAssertEqual(ls[2].debugName, "Marker #3")
		XCTAssertEqual(ls[3].debugName, "Marker #4")
	}
	
	func testAnchorWalking() {
		let markers = makeMarkers([
			GeoPlace(location: Vertex(11, 50), name: "1: Center", kind: .Region, rank: 1),
			GeoPlace(location: Vertex(11, 52), name: "No label fit", kind: .Region, rank: 2),
			GeoPlace(location: Vertex(12, 10), name: "2: North-East", kind: .City, rank: 1),
			GeoPlace(location: Vertex(12, 12), name: "3: South-East", kind: .City, rank: 2),
			GeoPlace(location: Vertex(12, 10), name: "4: North-West", kind: .City, rank: 3),
			GeoPlace(location: Vertex(12, 12), name: "5: South-West", kind: .City, rank: 4),
			GeoPlace(location: Vertex(11, 11), name: "No marker fit", kind: .City, rank: 5),
		])
		
		let (layout, _) = layouter.layoutLabels(markers: markers, projection: nullProjection)
		let ls = prepareForAsserts(layout)
		XCTAssertEqual(ls.count, 5)
		XCTAssertEqual(ls[0].debugName, "1: Center")
		XCTAssertEqual(ls[0].anchor, .Center)
		XCTAssertEqual(ls[1].debugName, "2: North-East")
		XCTAssertEqual(ls[1].anchor, .NE)
		XCTAssertEqual(ls[2].debugName, "3: South-East")
		XCTAssertEqual(ls[2].anchor, .SE)
		XCTAssertEqual(ls[3].debugName, "4: North-West")
		XCTAssertEqual(ls[3].anchor, .NW)
		XCTAssertEqual(ls[4].debugName, "5: South-West")
		XCTAssertEqual(ls[4].anchor, .SW)
	}
	
	func testStableLayoutOrdering() {
		let collidingMarkers = [
			GeoPlace(location: Vertex(5, 5), name: "Marker #1", kind: .City, rank: 1),
			GeoPlace(location: Vertex(5, 10), name: "Marker #2", kind: .City, rank: 2),
			GeoPlace(location: Vertex(5, 15), name: "Marker #3", kind: .City, rank: 3),
			GeoPlace(location: Vertex(5, 20), name: "Marker #4", kind: .City, rank: 4),
			GeoPlace(location: Vertex(5, 25), name: "Marker #5", kind: .City, rank: 5),
		]
		
		let markers = makeMarkers(collidingMarkers)
		let (layout1, _) = layouter.layoutLabels(markers: markers, projection: nullProjection)
		
		let shuffledMarkers = makeMarkers(collidingMarkers.shuffled())
		let (layout2, _) = layouter.layoutLabels(markers: shuffledMarkers, projection: offsetProjection)
		
		let ls1 = prepareForAsserts(layout1)
		let ls2 = prepareForAsserts(layout2)
		XCTAssertEqual(ls1[0].debugName, ls2[0].debugName)
		XCTAssertEqual(ls1[1].debugName, ls2[1].debugName)
		XCTAssertEqual(ls1[2].debugName, ls2[2].debugName)
		XCTAssertEqual(ls1[3].debugName, ls2[3].debugName)
		XCTAssertEqual(ls1[4].debugName, ls2[4].debugName)
	}
	
	func testNewMarkerPrioritization() {
		let markers = makeMarkers([
			GeoPlace(location: Vertex(5, 70), name: "Marker #6", kind: .Town, rank: 6),
			GeoPlace(location: Vertex(5, 70), name: "Marker #5", kind: .Town, rank: 5),
			GeoPlace(location: Vertex(5, 70), name: "Marker #4", kind: .Town, rank: 4),
			GeoPlace(location: Vertex(5, 50), name: "Marker #3", kind: .City, rank: 3),
			GeoPlace(location: Vertex(5, 30), name: "Marker #2", kind: .Capital, rank: 2),
			GeoPlace(location: Vertex(5, 10), name: "Marker #1", kind: .Region, rank: 1),
		])
		
		_ = layouter.layoutLabels(markers: markers, projection: nullProjection)
		XCTAssertEqual(layouter.orderedLayout.count, 5)	// 6th label rejected due to maxLabels
		XCTAssertEqual(layouter.orderedLayout[0].debugName, "Marker #1")
		XCTAssertEqual(layouter.orderedLayout[1].debugName, "Marker #2")
		XCTAssertEqual(layouter.orderedLayout[2].debugName, "Marker #3")
		XCTAssertEqual(layouter.orderedLayout[3].debugName, "Marker #4")
		XCTAssertEqual(layouter.orderedLayout[4].debugName, "Marker #5")
	}
	
	func testEjectedLabel() {
		let markers = makeMarkers([
			GeoPlace(location: Vertex(10, 10), name: "Marker A", kind: .City, rank: 1),
			GeoPlace(location: Vertex(32, 10), name: "Marker B", kind: .City, rank: 2),
			GeoPlace(location: Vertex(32, 32), name: "Marker C", kind: .City, rank: 3),
			GeoPlace(location: Vertex(10, 32), name: "Marker D", kind: .City, rank: 4),
			GeoPlace(location: Vertex(25, 25), name: "X", kind: .Town, rank: 5),
		])
		
		let (_, removed1) = layouter.layoutLabels(markers: markers, projection: nullProjection)
		XCTAssertEqual(layouter.orderedLayout.count, 5)
		XCTAssertEqual(removed1.count, 0)
		
		let (_, removed2) = layouter.layoutLabels(markers: markers, projection: zoomProjection)
		XCTAssertEqual(layouter.orderedLayout.count, 4)
		XCTAssertEqual(removed2.count, 1)
		XCTAssertEqual(markers[removed2[0]]!.name, "X")
	}
	
	func testRemoveFromLayout() {
		let markers = makeMarkers([
			GeoPlace(location: Vertex(5, 5), name: "Keep", kind: .City, rank: 1),
			GeoPlace(location: Vertex(5, 35), name: "Remove", kind: .City, rank: 2)
		])
		
		_ = layouter.layoutLabels(markers: markers, projection: nullProjection)
		layouter.removeLayout(for: markers.first!.value.ownerHash)
		XCTAssertEqual(layouter.orderedLayout.count, 1)
	}
	
	func testInsertionHysteresis() {
		layouter.labelMargin = 5.0
		let markers = makeMarkers([
			GeoPlace(location: Vertex(20, 20), name: "1: Upper", kind: .Region, rank: 1),
			GeoPlace(location: Vertex(20, 20 + 8 + 2), name: "2: In margin", kind: .Region, rank: 2),
			GeoPlace(location: Vertex(20, 20 + 8 + 5), name: "3: Outside margin", kind: .Region, rank: 2),
		])
		
		let (layout, _) = layouter.layoutLabels(markers: markers, projection: nullProjection)
		let ls = prepareForAsserts(layout)
		XCTAssertEqual(ls.count, 2)
		XCTAssertEqual(ls[0].debugName, "1: Upper")
		XCTAssertEqual(ls[1].debugName, "3: Outside margin")
	}
}
