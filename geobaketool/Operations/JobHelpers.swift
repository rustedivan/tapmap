//
//  JobHelpers.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//
import Foundation

typealias ProgressReport = (Double, String, Bool) -> ()
typealias ErrorReport = (String, String) -> ()

struct ToolGeoFeature : Equatable, Hashable, Codable {
	enum Level: String, Codable {
		case Continent = "continent"
		case Country = "country"
		case Province = "province"
	}
	typealias GeoStringProperties = [String : String]
	typealias GeoValueProperties = [String : Double]
	
	let level: Level
	let polygons: [Polygon]
	var tessellations: [GeoTessellation]
	var places: GeoPlaceCollection?
	var children: Set<ToolGeoFeature>?
	
	let stringProperties: GeoStringProperties
	let valueProperties: GeoValueProperties
	
	var name : String {
		return stringProperties["name"] ?? stringProperties["NAME"] ?? "Unnamed"
	}
	
	var countryKey : String {
		return stringProperties["COUNTRY"] ?? stringProperties["adm0_a3"] ?? stringProperties["ADM0_A3"] ?? "No admin"
	}
	
	var continentKey : String {
		return stringProperties["continent"] ?? stringProperties["CONTINENT"] ?? "No continent"
	}
	
	var uniqueCode : String {
		let code: String?
		switch level {
		case .Continent: code = String(name.prefix(2)).uppercased()
		case .Country: code = stringProperties["FIPS_10_"]
		case .Province:
			if let adm1 = stringProperties["adm1_code"], adm1.count > 0 {
				code = adm1
			} else if let dissMe = stringProperties["diss_me"], dissMe.count > 0 {
				code = dissMe
			} else if let fips = stringProperties["fips"], fips.count > 0 {
				code = fips
			} else {
				code = nil
			}
		}
		guard code != nil else {
			print("ERROR: \(name) has no unique identifier")
			exit(1)
		}
		return code!
	}
	
	func totalVertexCount() -> Int {
		return polygons.reduce(0) { $0 + $1.totalVertexCount() }
	}
	
	public static func == (lhs: ToolGeoFeature, rhs: ToolGeoFeature) -> Bool {
		return lhs.uniqueCode == rhs.uniqueCode && lhs.level == rhs.level && lhs.name == rhs.name 
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(uniqueCode)
		hasher.combine(level)
		hasher.combine(name)
	}
	
	var geographyId: RegionId {
		return RegionId(code: uniqueCode, level.rawValue, name)
	}
}

typealias ToolGeoFeatureMap = [RegionHash : ToolGeoFeature]
