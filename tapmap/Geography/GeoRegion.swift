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
	static func randomGreen() -> GeoColor {
		let r = 0.0 + Float(arc4random_uniform(50)) / 100.0
		let g = 0.5 + Float(arc4random_uniform(50)) / 100.0
		let b = 0.0 + Float(arc4random_uniform(50)) / 100.0
		return GeoColor(r: r, g: g, b: b)
	}
}

struct Vertex : Equatable {
	let x: Float
	let y: Float
	init(x _x: Float, y _y: Float) { x = _x; y = _y }
	init(x _x: Double, y _y: Double) { x = Float(_x); y = Float(_y) }
	
	static func ==(lhs: Vertex, rhs: Vertex) -> Bool {
		return fabsf(lhs.x - rhs.x) < .ulpOfOne && fabsf(lhs.y - rhs.y) < .ulpOfOne
	}
}

struct Triangle {
	let i: (Int, Int, Int)
}

struct Edge : Equatable {
	let v0: Vertex
	let v1: Vertex
	
	static func ==(lhs: Edge, rhs: Edge) -> Bool {
		let accuracy : Float = 0.001
		let notSame = (abs(lhs.v0.x - rhs.v0.x) > accuracy || abs(lhs.v0.y - rhs.v0.y) > accuracy ||
									 abs(lhs.v1.x - rhs.v1.x) > accuracy || abs(lhs.v1.y - rhs.v1.y) > accuracy)
		if notSame {
			let notFlipped = (abs(lhs.v0.x - rhs.v1.x) > accuracy || abs(lhs.v0.y - rhs.v1.y) > accuracy ||
									   		abs(lhs.v1.x - rhs.v0.x) > accuracy || abs(lhs.v1.y - rhs.v0.y) > accuracy)
			return !notFlipped
		}
		
		return true
	}
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

struct GeoRegion : Codable, Equatable, Hashable {
	let name: String
	let admin: String
	let geometry: GeoTessellation
	
	public static func == (lhs: GeoRegion, rhs: GeoRegion) -> Bool {
		return lhs.name == rhs.name && lhs.admin == rhs.admin
	}
	
	public var hashValue: Int {
		return (name + "." + admin).hashValue
	}
}

struct GeoTessellation : Codable {
	let vertices: [Vertex]
	let indices: [UInt32]
	let aabb: Aabb
}

struct GeoCountry : Codable, Equatable, Hashable {
	let geography: GeoRegion
	let regions: Set<GeoRegion>
	var name: String { get { return geography.name } }
	var admin: String { get { return geography.admin } }
	
	public static func == (lhs: GeoCountry, rhs: GeoCountry) -> Bool {
		return lhs.geography == rhs.geography
	}
	
	public var hashValue: Int {
		return geography.hashValue
	}
}

struct GeoContinent : Codable {
	let name: String
	let regions: [GeoRegion]
}

struct GeoWorld : Codable {
	let countries: Set<GeoCountry>
}
