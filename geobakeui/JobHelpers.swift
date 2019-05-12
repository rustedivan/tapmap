//
//  JobHelpers.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

typealias ProgressReport = (Double, String, Bool) -> ()
typealias ErrorReport = (String, String) -> ()

struct ToolGeoFeature : Equatable, Hashable {
	enum Level {
		case Continent
		case Country
		case Region
	}
	
	let level: Level
	let polygons: [Polygon]
	var tessellation: GeoTessellation?
	var places: GeoPlaceCollection?
	var children: Set<ToolGeoFeature>?
	
	let stringProperties: [String : String]
	let valueProperties: [String : Double]
	
	var name : String {
		return stringProperties["name"] ?? stringProperties["NAME"] ?? "Unnamed"
	}
	
	var countryKey : String {
		return stringProperties["adm0_a3"] ?? stringProperties["ADM0_A3"] ?? "No admin"
	}
	
	var continentKey : String {
		return stringProperties["continent"] ?? stringProperties["CONTINENT"] ?? "No continent"
	}
	
	func totalVertexCount() -> Int {
		return polygons.reduce(0) { $0 + $1.totalVertexCount() }
	}
	
	public static func == (lhs: ToolGeoFeature, rhs: ToolGeoFeature) -> Bool {
		return lhs.level == rhs.level && lhs.name == rhs.name && lhs.countryKey == rhs.countryKey
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(level)
		hasher.combine(name)
		hasher.combine(countryKey)
	}
}
