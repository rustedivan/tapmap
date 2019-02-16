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
	let indices: [UInt32]
	let aabb: Aabb
}

protocol Renderable {
	func renderPrimitive() -> RenderPrimitive
}

protocol GeoIdentifiable : Hashable {
	var name : String { get }
	var aabb : Aabb { get }
}

protocol GeoPlaceContainer {
	var places : Set<GeoPlace> { get }
	func placesRenderPlane() -> RenderPrimitive
}

protocol GeoTessellated : Renderable {
	var geometry : GeoTessellation { get }
}

protocol GeoNode : GeoIdentifiable {
	associatedtype SubType : GeoIdentifiable & Renderable
	var children : Set<SubType> { get }
}


struct GeoRegion : GeoIdentifiable, GeoPlaceContainer, GeoTessellated, Codable, Equatable {
	let name: String
	var geometry: GeoTessellation
	let places: Set<GeoPlace>
	var aabb : Aabb { return geometry.aabb }
	
	public static func == (lhs: GeoRegion, rhs: GeoRegion) -> Bool {
		return lhs.name == rhs.name && lhs.aabb.midpoint == rhs.aabb.midpoint
	}
	
	public var hashValue: Int {
		return ("\(name)@\(aabb.midpoint.quantized)").hashValue
	}
}

struct GeoCountry : GeoNode, GeoPlaceContainer, GeoTessellated, Codable, Equatable {
	typealias SubType = GeoRegion
	var name: String
	let children: Set<GeoRegion>
	let places: Set<GeoPlace>
	
	let geometry: GeoTessellation
	var aabb : Aabb { return geometry.aabb }
	
	
	public static func == (lhs: GeoCountry, rhs: GeoCountry) -> Bool {
		return lhs.name == rhs.name && lhs.aabb.midpoint == rhs.aabb.midpoint
	}
	
	public var hashValue: Int {
		return ("\(name)@\(aabb.midpoint.quantized)").hashValue
	}
}

struct GeoContinent : GeoNode, GeoTessellated, Codable, Equatable, Hashable {
	typealias SubType = GeoCountry
	
	var name: String
	
	let children: Set<GeoCountry>
	let geometry: GeoTessellation
	var aabb : Aabb { return geometry.aabb }
	
	public static func == (lhs: GeoContinent, rhs: GeoContinent) -> Bool {
		return lhs.name == rhs.name
	}
	
	public var hashValue: Int {
		return name.hashValue
	}
}

struct GeoWorld : GeoNode, Codable {
	typealias SubType = GeoContinent
	
	let name: String
	var aabb : Aabb { return Aabb(loX: -180.0, loY: -85.0, hiX: 180.0, hiY: 85.0) }
	
	let children: Set<GeoContinent>
}

struct GeoPlace : Codable, Equatable, Hashable {
	enum Kind: Int, Codable {
		case City
		case Town
	}
	
	let location: Vertex
	let name: String
	let kind: Kind
	
	public static func == (lhs: GeoPlace, rhs: GeoPlace) -> Bool {
		return lhs.name == rhs.name && lhs.location == rhs.location && lhs.kind == rhs.kind
	}
	
	public var hashValue: Int {
		return (name + "." + "(\(location.x):\(location.y))" + "." + "\(kind)").hashValue
	}
}

typealias GeoPlaceCollection = Set<GeoPlace>
