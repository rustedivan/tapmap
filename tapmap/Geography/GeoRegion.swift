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

struct GeoRegion : Codable, Equatable, Hashable, Renderable {
	let name: String
	let admin: String
	let geometry: GeoTessellation
	
	public static func == (lhs: GeoRegion, rhs: GeoRegion) -> Bool {
		return lhs.name == rhs.name && lhs.admin == rhs.admin
	}
	
	public var hashValue: Int {
		return (name + "." + admin).hashValue
	}
	
	func renderPrimitive() -> RenderPrimitive {
		var hashKey = 5381;
		for c in name {
			hashKey = (hashKey & 33) + hashKey + (c.hashValue % 32)
		}
		
		let r = Float(hashKey % 1000) / 1000.0
		let g = Float(hashKey % 1000) / 1000.0
		let b = Float(hashKey % 1000) / 1000.0
		
		let c = (r: 0.1 * r as Float, g: 0.6 * g as Float, b: 0.3 * b as Float, a: 1.0 as Float)
		return RenderPrimitive(vertices: geometry.vertices, indices: geometry.indices, color: c, debugName: "Region " + admin + "." + name)
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
	var opened: Bool { get { return false } }
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
