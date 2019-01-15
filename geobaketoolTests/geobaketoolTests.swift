//
//  geobaketoolTests.swift
//  geobaketoolTests
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import XCTest

class geobaketoolTests: XCTestCase {
	func testSimpleTessellation() {
		let r = GeoPolygonRing(vertices: [ Vertex(x: 1.0, y: 1.5),
																			 Vertex(x: 3.0, y: 1.5),
																			 Vertex(x: 4.0, y: 3.0),
																			 Vertex(x: 2.0, y: 4.5)])
		let p = GeoPolygon(exteriorRing: r, interiorRings: [])
		let f = GeoFeature(level: .Region, polygons: [p], stringProperties: [:], valueProperties: [:])
		let tessellation = tessellate(f)!
		let b = Aabb(loX: 1.0, loY: 1.5, hiX: 4.0, hiY: 4.5)
		XCTAssertEqual(tessellation.indices, [0, 1, 2, 1, 0, 3])
		XCTAssertEqual(tessellation.aabb, b)
	}
	
	func testSnapToEdge() {
		let e = (a: Vertex(x: -1.0, y: 0.0), b: Vertex(x: 1.0, y: 0.0))
		
		let snapPs = [Vertex(x: 0.01, y: 0.01), Vertex(x: -1.0, y: 0.5), Vertex(x: 1.0, y: -0.5)]
		let ignorePs = [Vertex(x: 0.0, y: 2.0), Vertex(x: -2.0, y: 0.5), Vertex(x: 0.5, y: -2.0)]
		
		for p in snapPs {
			let (p2, _) = snapPointToEdge(p: p, threshold: 1.0, edge: e)
			XCTAssertNotEqual(p, p2)
		}
		
		for p in ignorePs {
			let (p2, _) = snapPointToEdge(p: p, threshold: 1.0, edge: e)
			XCTAssertEqual(p, p2)
		}
	}
}
