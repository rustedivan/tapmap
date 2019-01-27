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
	
	func testFindSimilarEdges() {
		let e1 = Edge(v0: Vertex(x:  1.0001, y: -3.0003), v1: Vertex(x: -15.0015, y: 0.0000))
		let e2 = Edge(v0: Vertex(x:  1.0001, y: -3.0003), v1: Vertex(x: -15.0015, y: 0.0000))
		let e3 = Edge(v0: Vertex(x:-15.0015, y:  0.0000), v1: Vertex(x:   1.0001, y: -3.0003))
		let e4 = Edge(v0: Vertex(x:-15.0015, y:  0.0000), v1: Vertex(x:   2.0001, y: -3.0003))
		
		XCTAssertEqual(e1, e2, "Edges should be equal")
		XCTAssertEqual(e1, e3, "Edges should not be oriented")
		XCTAssertNotEqual(e1, e4, "Edges should not be equal")
	}
	
	func testCountEdgeNeighbors() {
		let v0 = Vertex(x: -5.0, y:  0.0)
		let v1 = Vertex(x:  0.0, y:  5.0)
		let v2 = Vertex(x:  0.0, y: -5.0)
		let v3 = Vertex(x:  5.0, y:  0.0)
		let v4 = Vertex(x: 10.0, y:  5.0)
		
		let ring1 = GeoPolygonRing(vertices: [v0, v1, v2])
		let ring2 = GeoPolygonRing(vertices: [v2, v1, v3])
		let ring3 = GeoPolygonRing(vertices: [v2, v3, v4])
		
		let edgeCardinalities = countEdgeCardinalities(rings: [ring1, ring2, ring3])
		
		let contourEdges = edgeCardinalities.filter { $0.1 == 1 }
		let innerEdges = edgeCardinalities.filter { $0.1 != 1 }
		XCTAssertEqual(contourEdges.count, 5)
		XCTAssertEqual(innerEdges.count, 2)
		
		XCTAssertTrue(innerEdges.map({ $0.0 }).contains(Edge(v0: v1, v1: v2)))
		XCTAssertTrue(innerEdges.map({ $0.0 }).contains(Edge(v0: v2, v1: v3)))
	}
	
	func testBuildEdgeRing() {
		let v0 = Vertex(x:  0.0, y:  0.0)
		let v1 = Vertex(x:  5.0, y:  5.0)
		let v2 = Vertex(x: 10.0, y: -5.0)
		let v3 = Vertex(x: 15.0, y: 10.0)
		let v4 = Vertex(x: 20.0, y:-10.0)
		
		let e0 = Edge(v0: v0, v1: v1)
		let e1 = Edge(v0: v1, v1: v2)
		let e2 = Edge(v0: v2, v1: v3)
		let e3 = Edge(v0: v3, v1: v4)
		let e4 = Edge(v0: v4, v1: v0)
		
		let orderedRing = GeoPolygonRing(edges: [e0, e1, e2, e3, e4])
		XCTAssertEqual(orderedRing.vertices, [v0, v1, v2, v3, v4])
		let unorderedEdges = [e0, e3, e1, e2, e4]
		let reorderedRing = buildContiguousEdgeRing(edges: unorderedEdges)!
		
		XCTAssertEqual(orderedRing.vertices, reorderedRing.vertices)
	}
	
	func testBuildContourFromRings() {
		let v0 = Vertex(x: -5.0, y:  0.0)
		let v1 = Vertex(x:  0.0, y:  5.0)
		let v2 = Vertex(x:  0.0, y: -5.0)
		let v3 = Vertex(x:  5.0, y:  0.0)
		let v4 = Vertex(x: 10.0, y:  5.0)
		
		let ring1 = GeoPolygonRing(vertices: [v0, v1, v2])
		let ring2 = GeoPolygonRing(vertices: [v2, v1, v3])
		let ring3 = GeoPolygonRing(vertices: [v2, v3, v4])
		
		let contour = buildContourOf(rings: [ring1, ring2, ring3])!
		XCTAssertEqual(contour.vertices, [v0, v1, v3, v4, v2])
	}
	

}
