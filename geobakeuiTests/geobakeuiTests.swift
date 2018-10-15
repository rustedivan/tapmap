//
//  geobakeuiTests.swift
//  geobakeuiTests
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import XCTest

class geobakeuiTests: XCTestCase {
	func testSimpleTessellation() {
		let r = GeoPolygonRing(vertices: [ Vertex(v: (1.0, 1.5)),
																			 Vertex(v: (3.0, 1.5)),
																			 Vertex(v: (4.0, 3.0)),
																			 Vertex(v: (2.0, 4.5))])
		let p = GeoPolygon(exteriorRing: r, interiorRings: [])
		let f = GeoFeature(polygons: [p], stringProperties: [:], valueProperties: [:])
		let tessellation = tessellate(f)!
		let b = Aabb(loX: 1.0, loY: 1.5, hiX: 4.0, hiY: 4.5)
		XCTAssertEqual(tessellation.indices, [0, 1, 2, 1, 0, 3])
		XCTAssertEqual(tessellation.aabb, b)
	}
}
