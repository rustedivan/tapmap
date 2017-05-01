//
//  geobakeuiTests.swift
//  geobakeuiTests
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import XCTest

class geobakeuiTests: XCTestCase {
    
    func testExample() {
			let v = [Vertex(v: (1.0, 1.0)),
			         Vertex(v: (3.0, 1.0)),
			         Vertex(v: (4.0, 3.0)),
			         Vertex(v: (2.0, 4.0))]

			let indices = tesselate(range: VertexRange(0, 4), ofVertices: v)
			XCTAssertEqual(indices, [0, 1, 3, 1, 4, 3])
    }
}
