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
	let report : ProgressReport
	var features : GeoFeatureCollection?

	init(json _json: JSON, reporter: @escaping ProgressReport) {
		json = _json
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		report(0.0, "Parsing places", false)
		features = parsePlaces(json: json)
		report(1.0, "Parsed places", true)
	}
	
	fileprivate func parsePlaces(json: JSON) -> GeoFeatureCollection? {
		guard let placeArray = json["elements"].array else {
			print("Did not find the \"elements\" array")
			return nil
		}
		
		let numPlaces = placeArray.count
		var loadedPlaces : Set<GeoFeature> = []
		
		for placeJson in placeArray {
			if let loadedPlace = parsePlace(placeJson) {
				loadedPlaces.insert(loadedPlace)
				report(Double(loadedPlaces.count) / Double(numPlaces), loadedPlace.name, false)
			}
		}
		
		return GeoFeatureCollection(features: loadedPlaces)
	}
	
	fileprivate func parsePlace(_ json: JSON) -> GeoFeature? {
		let properties = json["tags"]
		guard let featureName = properties["name:en"].string else {
			print("No name in place")
			return nil
		}
		
		let p = Vertex(json["lon"].doubleValue,
									 json["lat"].doubleValue)
		
		let starPolygon = GeoPolygon(exteriorRing: makeStar(around: p,
																												radius: 0.05,
																												points: 5),
																 interiorRings: [])
		
		return GeoFeature(level: .Country,
											polygons: [starPolygon],
											stringProperties: ["name":featureName],
											valueProperties: [:])
	}

	fileprivate func makeStar(around p: Vertex, radius: Float, points: Int) -> GeoPolygonRing {
		let vertices = 0..<points * 2
		let angles = vertices.map { (Double.pi / 2.0) + Double($0) * (2.0 * Double.pi / Double(points)) }
		let circle = angles.map { Vertex(cos($0), sin($0)) }
		let star = circle.enumerated().map { (offset: Int, element: Vertex) -> Vertex in
			let radius = (offset % 2 == 0) ? 1.0 : 0.6
			return Vertex(element.x * radius, element.y * radius)
		}
		let positionedStar = star.map { Vertex($0.x + p.x, $0.y + p.y) }
		return GeoPolygonRing(vertices: positionedStar)
	}
}
