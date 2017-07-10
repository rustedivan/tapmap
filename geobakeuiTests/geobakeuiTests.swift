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
		let v = [Vertex(v: (1.0, 1.5)),
						 Vertex(v: (3.0, 1.5)),
						 Vertex(v: (4.0, 3.0)),
						 Vertex(v: (2.0, 4.5))]
		let b = Aabb(loX: 1.0, loY: 1.5, hiX: 4.0, hiY: 4.5)
		let f = GeoFeature(vertexRange: VertexRange(0, 4))
		let r = GeoRegion(name: "temp", color: GeoColors.randomColor(), features: [f], tessellation: nil)
		
		let tessellation = tessellate(region: r, continentVertices: v)!
		let tr = GeoRegion.addTessellation(region: r, tessellation: tessellation)
		XCTAssertEqual(tr.tessellation!.indices, [0, 1, 2, 1, 0, 3])
		XCTAssertEqual(tr.tessellation!.aabb, b)
	}
	
	func testSerialisationVertex() {
		let v = Vertex(v: (2.0, -3.5))
		let d = NSKeyedArchiver.archivedData(withRootObject: v.encoded!)
		let v2 = (NSKeyedUnarchiver.unarchiveObject(with: d) as! Vertex.Coding).vertex!
		XCTAssertEqual(v2.v.0, 2.0)
		XCTAssertEqual(v2.v.1, -3.5)
	}
	
	func testSerialisationFeature() {
		let f = GeoFeature(vertexRange: VertexRange(5, 20))
		let d = NSKeyedArchiver.archivedData(withRootObject: f.encoded!)
		let f2 = (NSKeyedUnarchiver.unarchiveObject(with: d) as! GeoFeature.Coding).feature!
		XCTAssertEqual(f2.vertexRange.start, 5)
		XCTAssertEqual(f2.vertexRange.count, 20)
	}
	
	func testSerialisationRegion() {
		let v = Vertex(v: (2.0, -3.5))
		let v2 = Vertex(v: (1.0, -1.5))
		let f = GeoFeature(vertexRange: VertexRange(5, 20))
		let f2 = GeoFeature(vertexRange: VertexRange(5, 20))
		let t = GeoTessellation(vertices: [v, v2], indices: [0, 1], aabb: Aabb(loX: 1.0, loY: 2.0, hiX: 3.0, hiY: 4.0))
		let r = GeoRegion(name: "Test", color: GeoColor(r: 1.0, g: 2.0, b: 3.0), features: [f, f2], tessellation: t)
		let d = NSKeyedArchiver.archivedData(withRootObject: r.encoded!)
		let r2 = (NSKeyedUnarchiver.unarchiveObject(with: d) as! GeoRegion.Coding).region!
		XCTAssertEqual(r2.name, "Test")
//		XCTAssertEqual(r2.color.g, 2.0)
		XCTAssertEqual(r2.tessellation!.aabb.maxX, 3.0)
		XCTAssertEqual(r2.features.count, 2)
	}
	
	func testSerialisationContinent() {
		let v = Vertex(v: (-20.0, -33.5))
		let v2 = Vertex(v: (111.0, -13.5))
		let f = GeoFeature(vertexRange: VertexRange(5, 120))
		let f2 = GeoFeature(vertexRange: VertexRange(15, 210))
		let f3 = GeoFeature(vertexRange: VertexRange(25, 201))
		let f4 = GeoFeature(vertexRange: VertexRange(35, 2001))
		let t = GeoTessellation(vertices: [v, v2], indices: [0, 1], aabb: Aabb(loX: 1.0, loY: 2.0, hiX: 3.0, hiY: 4.0))
		let t2 = GeoTessellation(vertices: [v2, v], indices: [2, 3], aabb: Aabb(loX: -1.0, loY: -2.0, hiX: -3.0, hiY: -4.0))
		let r = GeoRegion(name: "Test", color: GeoColor(r: 1.0, g: 2.0, b: 3.0), features: [f, f2], tessellation: t)
		let r2 = GeoRegion(name: "Test2", color: GeoColor(r: 1.0, g: 2.0, b: 3.0), features: [f3, f4], tessellation: t2)
		
		let c = GeoContinent(name: "test", borderVertices: [v, v2], regions: [r, r2])
		let d = NSKeyedArchiver.archivedData(withRootObject: c.encoded!)
		let c2 = (NSKeyedUnarchiver.unarchiveObject(with: d) as! GeoContinent.Coding).continent!
		
		XCTAssertEqual(c2.name, "test")
		XCTAssertEqual(c2.borderVertices.count, 2)
		XCTAssertEqual(c2.regions.count, 2)
	}
	
	func testSerialisationWorld() {
		let v = Vertex(v: (-20.0, -33.5))
		let v2 = Vertex(v: (111.0, -13.5))
		let f = GeoFeature(vertexRange: VertexRange(5, 120))
		let f2 = GeoFeature(vertexRange: VertexRange(15, 210))
		let f3 = GeoFeature(vertexRange: VertexRange(25, 201))
		let f4 = GeoFeature(vertexRange: VertexRange(35, 2001))
		let t = GeoTessellation(vertices: [v, v2], indices: [0, 1], aabb: Aabb(loX: 1.0, loY: 2.0, hiX: 3.0, hiY: 4.0))
		let t2 = GeoTessellation(vertices: [v2, v], indices: [2, 3], aabb: Aabb(loX: -1.0, loY: -2.0, hiX: -3.0, hiY: -4.0))
		let r = GeoRegion(name: "Test", color: GeoColor(r: 1.0, g: 2.0, b: 3.0), features: [f, f2], tessellation: t)
		let r2 = GeoRegion(name: "Test2", color: GeoColor(r: 1.0, g: 2.0, b: 3.0), features: [f3, f4], tessellation: t2)
		let c = GeoContinent(name: "test1", borderVertices: [v, v2], regions: [r, r2])
		let c2 = GeoContinent(name: "test2", borderVertices: [v2, v], regions: [r2, r])
		
		let w = GeoWorld(continents: [c, c2])
		let d = NSKeyedArchiver.archivedData(withRootObject: w.encoded!)
		let w2 = (NSKeyedUnarchiver.unarchiveObject(with: d) as! GeoWorld.Coding).world!
		
		XCTAssertEqual(w2.continents.count, 2)
	}
}
