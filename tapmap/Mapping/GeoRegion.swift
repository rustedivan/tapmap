//
//  GeoRegion.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

// Swift's Hasher is randomized on each launch, so use these
// for values that need to be persisted into data.
struct RegionId: Codable {
	let key: String
	var hashed: Int = 0
	
	init(_ parent: String, _ level: String, _ name: String) {
		let fatKey = "\(parent) \(level) \(name)"
		key = fatKey.components(separatedBy: .punctuationCharacters).joined(separator: "")
								.components(separatedBy: .whitespaces).joined(separator: "-")
								.lowercased()
		hashed = RegionId.djb2Hash(key)
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.unkeyedContainer()
		try container.encode(key)
	}
	
	init(from decoder: Decoder) throws {
		var container = try decoder.unkeyedContainer()
		key = try container.decode(String.self)
		hashed = RegionId.djb2Hash(key)
	}
	
	private static func djb2Hash(_ key: String) -> RegionHash {
		var hash = 5381
		for char in key {
			let charCode = Int(char.unicodeScalars.first!.value)
			hash = hash &* 33 &+ charCode	// Note the overflow operators
		}

		return hash
	}
}
typealias RegionHash = Int


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
	let contours: [VertexRing]
	let aabb: Aabb
	let midpoint: Vertex
}

protocol GeoIdentifiable : Hashable {
	var name : String { get }
	var aabb : Aabb { get }
	var geographyId: RegionId { get }
}

protocol GeoPlaceContainer {
	var places : Set<GeoPlace> { get }
	func poiRenderPlanes() -> [PoiPlane]
}

protocol GeoNode : GeoIdentifiable {
	associatedtype SubType : GeoIdentifiable
	var children : Set<SubType> { get }
}


struct GeoProvince : GeoIdentifiable, GeoPlaceContainer, Codable, Equatable {
	let name: String
	let places: Set<GeoPlace>
	let geographyId: RegionId
	let aabb: Aabb
	
	public static func == (lhs: GeoProvince, rhs: GeoProvince) -> Bool {
		return lhs.name == rhs.name && lhs.aabb.midpoint == rhs.aabb.midpoint
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(geographyId.key)
	}
}

struct GeoCountry : GeoNode, GeoPlaceContainer, Codable, Equatable {
	typealias SubType = GeoProvince
	let name: String
	let children: Set<GeoProvince>
	let places: Set<GeoPlace>
	let geographyId: RegionId
	let aabb: Aabb
	
	public static func == (lhs: GeoCountry, rhs: GeoCountry) -> Bool {
		return lhs.name == rhs.name && lhs.aabb.midpoint == rhs.aabb.midpoint
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(geographyId.key)
	}
}

struct GeoContinent : GeoNode, GeoPlaceContainer, Codable, Equatable, Hashable {
	typealias SubType = GeoCountry
	let name: String
	let children: Set<GeoCountry>
	let places: Set<GeoPlace>
	let geographyId: RegionId
	let aabb: Aabb
	
	public static func == (lhs: GeoContinent, rhs: GeoContinent) -> Bool {
		return lhs.name == rhs.name
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(geographyId.key)
	}
}

struct GeoWorld : GeoNode, Codable {
	let name: String
	var aabb : Aabb { return Aabb(loX: -180.0, loY: -85.0, hiX: 180.0, hiY: 85.0) }
	let children: Set<GeoContinent>
	let geographyId = RegionId("universe", "planet", "Earth")
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(geographyId.key)
	}
	
	public static func == (lhs: GeoWorld, rhs: GeoWorld) -> Bool {
		return lhs.name == rhs.name
	}
}

struct GeoPlace : Codable, Equatable, Hashable {
	enum Kind: Int, Codable {
		case Capital
		case City
		case Town
		case Region
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
