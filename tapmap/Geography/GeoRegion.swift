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
		let accuracy : Float = 0.01
		return fabsf(lhs.x - rhs.x) < accuracy && fabsf(lhs.y - rhs.y) < accuracy
	}
}

struct Triangle {
	let i: (Int, Int, Int)
}

struct Edge : Equatable, Hashable, PointForm {
	let v0: Vertex
	let v1: Vertex
	
	var p : Vertex { return v0 }
	
	static func ==(lhs: Edge, rhs: Edge) -> Bool {
		return (lhs.v0 == rhs.v0 && lhs.v1 == rhs.v1) || (lhs.v0 == rhs.v1 && lhs.v1 == rhs.v0)
	}
	
	var hashValue : Int {
		let accuracy : Float = 0.01
		var leftToRight = (v0, v1)
		
		if abs(v0.x - v1.x) < accuracy {
			if v1.y < v0.y {
				leftToRight = (v1, v0)
			}
		} else if v1.x < v0.x {
			leftToRight = (v1, v0)
		}
		
		return String(format: "%.3f-%.3f|%.3f-%.3f",
									arguments: [leftToRight.0.x, leftToRight.0.y, leftToRight.1.x, leftToRight.1.y]).hashValue
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
	let continent: String
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
	var continent: String { get { return geography.continent } }
	
	public static func == (lhs: GeoCountry, rhs: GeoCountry) -> Bool {
		return lhs.geography == rhs.geography
	}
	
	public var hashValue: Int {
		return geography.hashValue
	}
}

struct GeoContinent : Codable, Equatable, Hashable {
	let geography: GeoRegion
	let countries: Set<GeoCountry>
	
	var name: String { get { return geography.name } }
	
	public static func == (lhs: GeoContinent, rhs: GeoContinent) -> Bool {
		return lhs.geography == rhs.geography
	}
	
	public var hashValue: Int {
		return geography.hashValue
	}
}

struct GeoWorld : Codable {
	let continents: Set<GeoContinent>
}
