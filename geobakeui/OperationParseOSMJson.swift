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
		let possibleNames = properties["name:en"].string ?? properties["name"].string
		
		guard let x = json["lon"].double, let y = json["lat"].double else {
			print("Place has no lat/lon data.")
			return nil
		}
		let p = Vertex(x, y)
		
		guard let featureName = possibleNames else {
			print("No name in place located at \(p)")
			return nil
		}
		
		return GeoPlace(location: p,
										name: featureName,
										kind: kind)
	}
}
