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

struct Triangle {
	let i: (Int, Int, Int)
}

struct Aabb : Equatable, Codable {
	let minX : Vertex.Precision
	let minY : Vertex.Precision
	let maxX : Vertex.Precision
	let maxY : Vertex.Precision
	
	init() {
		minX = .greatestFiniteMagnitude
		minY = .greatestFiniteMagnitude
		maxX = -.greatestFiniteMagnitude
		maxY = -.greatestFiniteMagnitude
	}
	
	init(loX : Vertex.Precision, loY : Vertex.Precision, hiX : Vertex.Precision, hiY : Vertex.Precision) {
		minX = loX
		minY = loY
		maxX = hiX
		maxY = hiY
	}
	
	var midpoint: Vertex { return Vertex(Vertex.Precision(minX + ((maxX - minX) / 2.0)),
																			 Vertex.Precision(minY + ((maxY - minY) / 2.0))) }
	
	static func ==(lhs: Aabb, rhs: Aabb) -> Bool {
		return	lhs.minX == rhs.minX &&
						lhs.maxX == rhs.maxX &&
						lhs.minY == rhs.minY &&
						lhs.maxY == rhs.maxY
	}
}

struct GeoTessellation : Codable {
	let vertices: [Vertex]
	let aabb: Aabb
	let midpoint: Vertex
}

protocol Renderable {
	associatedtype PrimitiveType
	func renderPrimitive() -> PrimitiveType
}

protocol GeoIdentifiable : Hashable {
	var name : String { get }
	var aabb : Aabb { get }
	var parentHash: Int { get }
}

protocol GeoPlaceContainer {
	var places : Set<GeoPlace> { get }
	func poiRenderPlanes() -> [PoiPlane]
}

protocol GeoTessellated : Renderable {
	var geometry : GeoTessellation { get }
	var contours : [VertexRing] { get }
}

protocol GeoNode : GeoIdentifiable {
	associatedtype SubType : GeoIdentifiable & GeoTessellated
	var children : Set<SubType> { get }
}


struct GeoRegion : GeoIdentifiable, GeoPlaceContainer, GeoTessellated, Codable, Equatable {
	let name: String
	let geometry: GeoTessellation
	let contours: [VertexRing]
	let places: Set<GeoPlace>
	let parentHash: Int
	var aabb : Aabb { return geometry.aabb }
	
	public static func == (lhs: GeoRegion, rhs: GeoRegion) -> Bool {
		return lhs.name == rhs.name && lhs.aabb.midpoint == rhs.aabb.midpoint
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(aabb.midpoint.quantized.0)
		hasher.combine(aabb.midpoint.quantized.1)
	}
}

struct GeoCountry : GeoNode, GeoPlaceContainer, GeoTessellated, Codable, Equatable {
	typealias SubType = GeoRegion
	let name: String
	let children: Set<GeoRegion>
	let places: Set<GeoPlace>
	let geometry: GeoTessellation
	let contours: [VertexRing]
	let parentHash: Int
	var aabb : Aabb { return geometry.aabb }
	
	
	public static func == (lhs: GeoCountry, rhs: GeoCountry) -> Bool {
		return lhs.name == rhs.name && lhs.aabb.midpoint == rhs.aabb.midpoint
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(aabb.midpoint.quantized.0)
		hasher.combine(aabb.midpoint.quantized.1)
	}
}

struct GeoContinent : GeoNode, GeoTessellated, GeoPlaceContainer, Codable, Equatable, Hashable {
	typealias SubType = GeoCountry
	let name: String
	let children: Set<GeoCountry>
	let places: Set<GeoPlace>
	let geometry: GeoTessellation
	let contours: [VertexRing]
	let parentHash: Int
	var aabb : Aabb { return geometry.aabb }
	
	public static func == (lhs: GeoContinent, rhs: GeoContinent) -> Bool {
		return lhs.name == rhs.name
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(name)
	}
}

struct GeoWorld : GeoNode, Codable {
	let name: String
	var aabb : Aabb { return Aabb(loX: -180.0, loY: -85.0, hiX: 180.0, hiY: 85.0) }
	let children: Set<GeoContinent>
	let parentHash: Int
}

struct GeoPlace : Codable, Equatable, Hashable {
	enum Kind: Int, Codable {
		case Capital
		case City
		case Town
	}
	
	let location: Vertex
	let name: String
	let kind: Kind
	let rank: Int
	
	public static func == (lhs: GeoPlace, rhs: GeoPlace) -> Bool {
		return lhs.name == rhs.name && lhs.location == rhs.location && lhs.kind == rhs.kind
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(location.quantized.0)
		hasher.combine(location.quantized.1)
		hasher.combine(kind)
	}
}

typealias GeoPlaceCollection = Set<GeoPlace>
