//
//  geobakeuiTests.swift
//  geobakeuiTests
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import XCTest

class geobakeuiTests: XCTestCase {
	func testSimpleTesselation() {
		let v = [Vertex(v: (1.0, 1.5)),
						 Vertex(v: (3.0, 1.5)),
						 Vertex(v: (4.0, 3.0)),
						 Vertex(v: (2.0, 4.5))]
		let b = Aabb(loX: 1.0, loY: 1.5, hiX: 4.0, hiY: 4.5)
		let f = GeoFeature(vertexRange: VertexRange(0, 4))
		let r = GeoRegion(name: "temp", color: GeoColors.randomColor(), features: [f], tesselation: nil)
		
		let tesselation = tesselate(region: r, continentVertices: v)!
		let tr = GeoRegion.addTesselation(region: r, tesselation: tesselation)
		XCTAssertEqual(tr.tesselation!.indices, [0, 1, 2, 1, 0, 3])
		XCTAssertEqual(tr.tesselation!.aabb, b)
	}
}
