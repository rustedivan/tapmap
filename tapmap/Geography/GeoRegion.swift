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
		let r = 0.0 + Float(arc4random_uniform(50)) / 100.0
		let g = 0.5 + Float(arc4random_uniform(50)) / 100.0
		let b = 0.0 + Float(arc4random_uniform(50)) / 100.0
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

struct GeoRegion : Codable {
	let name: String
	let color: GeoColor
	let geometry: GeoTessellation
}

struct GeoTessellation : Codable {
	let vertices: [Vertex]
	let indices: [UInt32]
	let aabb: Aabb
}

struct GeoContinent : Codable {
	let name: String
	let regions: [GeoRegion]
}

struct GeoWorld : Codable {
	let continents: [GeoContinent]
}
