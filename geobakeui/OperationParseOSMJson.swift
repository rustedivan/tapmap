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
	let json : JSON
	let kind : GeoPlace.Kind
	let report : ProgressReport
	var places : GeoPlaceCollection?

	init(json _json: JSON, kind _kind: GeoPlace.Kind, reporter: @escaping ProgressReport) {
		json = _json
		kind = _kind
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		report(0.0, "Parsing places", false)
		places = parsePlaces(json: json, asKind: kind)
		report(1.0, "Parsed places", true)
	}
	
	fileprivate func parsePlaces(json: JSON, asKind kind: GeoPlace.Kind) -> GeoPlaceCollection? {
		guard let placeArray = json["elements"].array else {
			print("Did not find the \"elements\" array")
			return nil
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
		guard let featureName = properties["name:en"].string else {
			print("No name in place")
			return nil
		}
		
		let p = Vertex(json["lon"].doubleValue,
									 json["lat"].doubleValue)
		
		return GeoPlace(location: p,
										name: featureName,
										kind: kind)
	}
}
