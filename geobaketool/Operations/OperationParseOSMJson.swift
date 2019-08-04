//
//  OperationParseOSMJson.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-02-09.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON

class OperationParseOSMJson : Operation {
	let input : JSON
	let kind : GeoPlace.Kind
	let report : ProgressReport
	var output : GeoPlaceCollection?

	init(json _json: JSON, kind _kind: GeoPlace.Kind, reporter: @escaping ProgressReport) {
		input = _json
		kind = _kind
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		report(0.0, "Parsing places", false)
		output = parsePlaces(json: input, asKind: kind)
		report(1.0, "Parsed places", true)
	}
	
	fileprivate func parsePlaces(json: JSON, asKind kind: GeoPlace.Kind) -> GeoPlaceCollection? {
		guard let placeArray = json["elements"].array else {
			print("Did not find the \"elements\" array")
			return GeoPlaceCollection()
		}
		
		let numPlaces = placeArray.count
		var loadedPlaces : Set<GeoPlace> = []
		
		for placeJson in placeArray {
			if let loadedPlace = parsePlace(placeJson, asKind: kind) {
				loadedPlaces.insert(loadedPlace)
				report(Double(loadedPlaces.count) / Double(numPlaces), loadedPlace.name, false)
			}
		}
		
		return GeoPlaceCollection(loadedPlaces)
	}
	
	fileprivate func parsePlace(_ json: JSON, asKind kind: GeoPlace.Kind) -> GeoPlace? {
		let properties = json["tags"]
		let possibleNames = properties["name:en"].string ?? properties["name"].string
		let adminLevel = properties["admin_level"].int ?? 4	// Assume mid-range if missing
		let knownCapital = (properties["capital"].stringValue == "yes" || adminLevel <= 2)	// Admin level 1-2 seem to be capitals too
		
		guard let x = json["lon"].double, let y = json["lat"].double else {
			print("Place has no lat/lon data.")
			return nil
		}
		let p = Vertex(x, y)
		
		guard let featureName = possibleNames else {
			print("No name in place located at \(p)")
			return nil
		}
		
		let decoratedPlaceKind: GeoPlace.Kind
		switch (kind, knownCapital) {
			case (.City, true): decoratedPlaceKind = .Capital
			default: decoratedPlaceKind = kind
		}
		
		let rank = determineRank(kind: decoratedPlaceKind, name: featureName, adminLevel: adminLevel, population: properties["population"].int)
		
		return GeoPlace(location: p,
										name: featureName,
										kind: decoratedPlaceKind,
										rank: rank)
	}
	
	fileprivate func determineRank(kind: GeoPlace.Kind, name: String, adminLevel: Int?, population: Int?) -> Int {
		let logPopulation: Double? = population != nil ? log(Double(population!)) : nil
		
		switch (kind, adminLevel, logPopulation) {
		case (.Capital, _, let logPop?) where logPop > 6.5:	// Capital over 5M population
			return 1
		case (.Capital, _, _):															// Normal capital
			return 2
		case (.City, _, let logPop?) where logPop > 6:			// City over 1M population
			return 3
		case (.City, _, let logPop?) where logPop > 5:			// City over 100k population
			return 4
		case (.City, _, let logPop?) where logPop > 4:			// City over 10k population
			return 5
		case (.City, _, .some):							// City know to be below 10k population
			return 6
		case (.City, let level?, .none):										// City with only admin level known can be 3-6
			return min(max(level, 3), 6)
		case (.City, .none, .none):													// Cities fallback to 5
			print("City \(name) has no admin level and no population")
			return 5
		case (.Town, .none, let logPop?):										// Towns with population can be 6-8
			return Int(min(max(logPop, 6), 8))
		case (.Town, let level?, _):												// Town with only admin level known can be 6-8
			return min(max(level, 6), 8)
		case (.Town, .none, .none):													// Towns fallback to 7
			print("Town \(name) has no admin level and no population")
			return 7
		}
	}
}
