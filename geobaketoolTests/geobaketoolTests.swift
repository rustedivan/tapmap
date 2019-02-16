//
//  geobaketoolTests.swift
//  geobaketoolTests
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import XCTest

func silentReport(_: Double, _:String, _:Bool) {
	
}

class geobaketoolTests: XCTestCase {
	func testSimpleTessellation() {
		let r = VertexRing(vertices: [ Vertex(1.0, 1.5),
																			 Vertex(3.0, 1.5),
																			 Vertex(4.0, 3.0),
																			 Vertex(2.0, 4.5)])
		let p = Polygon(exteriorRing: r, interiorRings: [])
		let f = ToolGeoFeature(level: .Region,
													 polygons: [p],
													 tessellation: nil,
													 places: nil,
													 children: nil,
													 stringProperties: [:],
													 valueProperties: [:])
		let tessellation = tessellate(f)!
		let b = Aabb(loX: 1.0, loY: 1.5, hiX: 4.0, hiY: 4.5)
		XCTAssertEqual(tessellation.indices, [0, 1, 2, 1, 0, 3])
		XCTAssertEqual(tessellation.aabb, b)
	}

	func testSnapToEdge() {
		let e = (a: Vertex(-1.0, 0.0), b: Vertex(1.0, 0.0))

		let snapPs = [Vertex(0.01, 0.01), Vertex(-1.0, 0.5), Vertex(1.0, -0.5)]
		let ignorePs = [Vertex(0.0, 2.0), Vertex(-2.0, 0.5), Vertex(0.5, -2.0)]

		for p in snapPs {
			let (p2, _) = snapPointToEdge(p: p, threshold: 1.0, edge: e)
			XCTAssertNotEqual(p, p2)
		}

		for p in ignorePs {
			let (p2, _) = snapPointToEdge(p: p, threshold: 1.0, edge: e)
			XCTAssertEqual(p, p2)
		}
	}

	func testFindSimilarEdges() {
		let e1 = Edge(Vertex(1.00000001, -3.000000003), Vertex(-15.0015, 0.0000))
		let e2 = Edge(Vertex(1.00000002, -3.000000004), Vertex(-15.0015, 0.0000))
		let e3 = Edge(Vertex(-15.0015, 0.0000), Vertex(1.00000001, -3.000000003))
		let e4 = Edge(Vertex(-15.0015, 0.0000), Vertex(1.0001, -3.000000003))

		XCTAssertEqual(e1, e2, "Edges should be equal")
		XCTAssertEqual(e1, e3, "Edges should not be oriented")
		XCTAssertNotEqual(e1, e4, "Edges should not be equal")
	}

	func testAccurateEdgeHashing() {
		let v0u = Vertex(117.75388716, -300.0003)
		let v0d = Vertex(117.75388714, -300.0003)
		let v1 =  Vertex(-13.01241243, -300.0003)
		let v2 =  Vertex(117.75388814, -300.0003)
		//											  ^--- differing from v0u in this decimal
		// Equal within small error
		let e1 = Edge(v0u, v1)
		let e2 = Edge(v0d, v1)
		
		let e2Flipped = Edge(v1, v0d)
		
		// Unequal, error in 1e-5
		let e3 = Edge(v2, v1)
		
		print(v2.quantized)
		print(v0d.quantized)
		
		XCTAssertEqual(e1.hashValue, e2.hashValue, "Edges should be equal")
		XCTAssertEqual(e1.hashValue, e2Flipped.hashValue, "Flipped edges should be equal")
		XCTAssertNotEqual(e2.hashValue, e3.hashValue, "Edges should not be equal")
	}

	func testCountEdgeNeighbors() {
		let v0 = Vertex(-5.0, 0.0)
		let v1 = Vertex(0.0, 5.0)
		let v2 = Vertex(0.0, -5.0)
		let v3 = Vertex(5.0, 0.0)
		let v4 = Vertex(10.0, 5.0)

		let ring1 = VertexRing(vertices: [v0, v1, v2])
		let ring2 = VertexRing(vertices: [v2, v1, v3])
		let ring3 = VertexRing(vertices: [v2, v3, v4])

		let edgeCardinalities = countEdgeCardinalities(rings: [ring1, ring2, ring3])

		let contourEdges = edgeCardinalities.filter { $0.1 == 1 }
		let innerEdges = edgeCardinalities.filter { $0.1 != 1 }
		XCTAssertEqual(contourEdges.count, 5)
		XCTAssertEqual(innerEdges.count, 2)

		XCTAssertTrue(innerEdges.map({ $0.0 }).contains(Edge(v1, v2)))
		XCTAssertTrue(innerEdges.map({ $0.0 }).contains(Edge(v2, v3)))
	}
	
	func testAccurateEdgeCardinalities() {
		let v0 = Vertex(12.53597015, -12.428317)
		let v1 = Vertex(12.53597748, -12.438571)
		let v2 = Vertex(12.53575612, -12.436781)
		let v3 = Vertex(12.53597119, -12.428317)
		let v4 = Vertex(12.64597015, -13.428317)
		
		print(v0.hashValue)
		print(v1.hashValue)
		print(v2.hashValue)
		print(v3.hashValue)
		print(v4.hashValue)
		
		let ring1 = VertexRing(vertices: [v0, v1, v2, v3, v4])
		let edgeCardinalities = countEdgeCardinalities(rings: [ring1])
		XCTAssertEqual(edgeCardinalities.count, 5)
	}

	func testBuildEdgeRing() {
		let v0 = Vertex(0.0, 0.0)
		let v1 = Vertex(5.0, 5.0)
		let v2 = Vertex(10.0, -5.0)
		let v3 = Vertex(15.0, 10.0)
		let v4 = Vertex(20.0, -10.0)

		let e0 = Edge(v0, v1)
		let e1 = Edge(v1, v2)
		let e2 = Edge(v2, v3)
		let e3 = Edge(v3, v4)
		let e4 = Edge(v4, v0)

		let orderedRing = VertexRing(edges: [e0, e1, e2, e3, e4])
		XCTAssertEqual(orderedRing.vertices, [v0, v1, v2, v3, v4])
		let unorderedEdges = [e0, e3, e1, e2, e4]
		let reorderedRing = buildContiguousEdgeRings(edges: unorderedEdges, report: silentReport)[0]

		XCTAssertEqual(orderedRing.vertices, reorderedRing.vertices)
	}

	func testBuildContourFromRings() {
		let v0 = Vertex(-5.0, 0.0)
		let v1 = Vertex(0.0, 5.0)
		let v2 = Vertex(0.0, -5.0)
		let v3 = Vertex(5.0, 0.0)
		let v4 = Vertex(15.0, 5.0)

		let ring1 = VertexRing(vertices: [v0, v1, v2])
		let ring2 = VertexRing(vertices: [v2, v1, v3])
		let ring3 = VertexRing(vertices: [v2, v3, v4])

		let contour = buildContourOf(rings: [ring1, ring2, ring3], report: silentReport)[0]
		XCTAssertTrue(contour.vertices.contains(v0))
		XCTAssertTrue(contour.vertices.contains(v1))
		XCTAssertTrue(contour.vertices.contains(v2))
		XCTAssertTrue(contour.vertices.contains(v3))
		XCTAssertTrue(contour.vertices.contains(v4))
	}
	
	func testRemoveProblem() {
		var t : KDNode<Vertex>
			=	kdInsert(v: Vertex(0.0, 5.0), n: .Empty)
		t = kdInsert(v: Vertex(0.0, 0.0), n: t)
		t = kdInsert(v: Vertex(-5.0, 0.0), n: t)
		t = kdInsert(v: Vertex(-5.0, -5.0), n: t)
		t = kdInsert(v: Vertex(-5.0, 5.0), n: t)
		t = kdInsert(v: Vertex(0.0, -5.0), n: t)

		t = kdRemove(v: Vertex(0.0, 5.0), n: t)
		let hardPointToRemove = Vertex(0.0, -5.0)
		t = kdRemove(v: hardPointToRemove, n: t)
		
		let startResult = (bestPoint: Vertex(0.0, 0.0), bestDistance: 10000.0)
		XCTAssertNotEqual(kdFindNearest(query: hardPointToRemove, node: t,
																		d: .x, aabb: CGRect(x: -10.0, y: -10.0, width: 20.0, height: 20.0),
																		result: startResult).bestPoint, hardPointToRemove)
	}
	
	func testBuildContoursFromAccurateData() {
		let v0 = Vertex(-0.000005, -0.000000)
		let v1 = Vertex( 0.000000,  0.000005)
		let v2 = Vertex( 0.000000, -0.000005)
		let v3 = Vertex( 0.000005,  0.000000)
		let v4 = Vertex( 0.000015,  0.000005)
		
		let ring1 = VertexRing(vertices: [v0, v1, v2, v3, v4])
		
		let contour = buildContourOf(rings: [ring1], report: silentReport)[0]
		XCTAssertTrue(contour.vertices.contains(v0))
		XCTAssertTrue(contour.vertices.contains(v1))
		XCTAssertTrue(contour.vertices.contains(v2))
		XCTAssertTrue(contour.vertices.contains(v3))
		XCTAssertTrue(contour.vertices.contains(v4))
	}
	
	func testBuildContoursFromIslands() {
		let v10 = Vertex(-5.0, 0.0)
		let v11 = Vertex(0.0, 5.0)
		let v12 = Vertex(0.0, -5.0)

		let v20 = Vertex(-5.0, 5.0)
		let v21 = Vertex(0.0, 0.0)
		let v22 = Vertex(-5.0, -5.0)

		let ring1 = VertexRing(vertices: [v10, v11, v12])
		let ring2 = VertexRing(vertices: [v20, v21, v22])

		let contour = buildContourOf(rings: [ring1, ring2], report: silentReport)
		XCTAssertEqual(contour.count, 2)
	}
}
