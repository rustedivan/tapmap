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

struct GeoFeature : Equatable, Hashable {
	let polygons: [GeoPolygon]
	let stringProperties: [String : String]
	let valueProperties: [String : Double]
	
	var name : String {
		return stringProperties["name"] ?? stringProperties["NAME"] ?? "Unnamed"
	}
	
	var admin : String {
		return stringProperties["adm0_a3"] ?? stringProperties["ADM0_A3"] ?? "Unnamed"
	}
	
	func totalVertexCount() -> Int {
		return polygons.reduce(0) { $0 + $1.totalVertexCount() }
	}
	
	public static func == (lhs: GeoFeature, rhs: GeoFeature) -> Bool {
		return lhs.name == rhs.name && lhs.admin == rhs.admin
	}
	
	public var hashValue: Int {
		return name.hashValue ^ admin.hashValue
	}
}

struct GeoFeatureCollection {
	let features: Set<GeoFeature>
	
	func totalVertexCount() -> Int {
		return features.reduce(0) { $0 + $1.totalVertexCount() }
	}
}
