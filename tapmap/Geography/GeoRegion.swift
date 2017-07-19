//
//  GeoRegion.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

struct GeoColor : Codable {
	let r, g, b: Float
}

struct GeoColors : Codable {
	static func randomColor() -> GeoColor {
		let r = Float(arc4random_uniform(100)) / 100.0
		let g = Float(arc4random_uniform(100)) / 100.0
		let b = Float(arc4random_uniform(100)) / 100.0
		return GeoColor(r: r, g: g, b: b)
	}
}

struct Vertex {
	let v: (Float, Float)
}

struct Triangle {
	let i: (Int, Int, Int)
}

struct Aabb : Equatable, Codable {
	let minX : Float
	let minY : Float
	let maxX : Float
	let maxY : Float
	
	init() {
		minX = .greatestFiniteMagnitude
		minY = .greatestFiniteMagnitude
		maxX = -.greatestFiniteMagnitude
		maxY = -.greatestFiniteMagnitude
	}
	
	init(loX : Float, loY : Float, hiX : Float, hiY : Float) {
		minX = loX
		minY = loY
		maxX = hiX
		maxY = hiY
	}
	
	static func ==(lhs: Aabb, rhs: Aabb) -> Bool {
		return	lhs.minX == rhs.minX &&
						lhs.maxX == rhs.maxX &&
						lhs.minY == rhs.minY &&
						lhs.maxY == rhs.maxY
	}
}

typealias VertexRange = (start: UInt32, count: UInt32)

struct GeoFeature {
	let vertexRange: VertexRange
}

struct GeoRegion : Codable {
	let name: String
	let color: GeoColor
	let features: [GeoFeature]
	var tessellation: GeoTessellation?
	
	static func addTessellation(region: GeoRegion, tessellation: GeoTessellation) -> GeoRegion {
		return GeoRegion(name: region.name, color: region.color, features: region.features, tessellation: tessellation)
	}
}

struct GeoTessellation : Codable {
	let vertices: [Vertex]
	let indices: [UInt32]
	let aabb: Aabb
}

struct GeoContinent : Codable {
	let name: String
	let borderVertices: [Vertex]
	let regions: [GeoRegion]
}

struct GeoWorld : Codable {
	let continents: [GeoContinent]
}
