//
//  ToolGeometry.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-11-30.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

struct GeoPolygonRing {
	let vertices: [Vertex]
}

struct GeoPolygon {
	let exteriorRing: GeoPolygonRing
	let interiorRings: [GeoPolygonRing]
	
	func totalVertexCount() -> Int {
			return exteriorRing.vertices.count +
						 interiorRings.reduce(0) { $0 + $1.vertices.count }
	}
}

struct GeoFeature {
	let polygons: [GeoPolygon]
	let stringProperties: [String : String]
	let valueProperties: [String : Double]
	
	var name : String {
		return stringProperties["name"] ?? stringProperties["NAME"] ?? "Unnamed"
	}
	
	var admin : String {
		return stringProperties["admin"] ?? stringProperties["ADMIN"] ?? "Unnamed"
	}
	
	func totalVertexCount() -> Int {
		return polygons.reduce(0) { $0 + $1.totalVertexCount() }
	}
}

struct GeoFeatureCollection {
	let features: [GeoFeature]
	
	func totalVertexCount() -> Int {
		return features.reduce(0) { $0 + $1.totalVertexCount() }
	}
}
