//
//  OperationParseGeoJson.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-16.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON

class OperationParseGeoJson : Operation {
	let json : JSON
	let report : ProgressReport
	var continents : [GeoMultiFeature]?
	
	init(_ geoJson: JSON, reporter: @escaping ProgressReport) {
		json = geoJson
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		var loadedContinents: [GeoMultiFeature] = []
		let numContinents = json.dictionaryValue.keys.count

		for continentJson in json.dictionaryValue.values {
			let loadedContinent = parseContinent(continentJson)
			loadedContinents.append(loadedContinent)

			report(Double(loadedContinents.count) / Double(numContinents), loadedContinent.name, false)
		}
		
		continents = loadedContinents
		
	}
	
	fileprivate func parseContinent(_ json: JSON) -> GeoMultiFeature {
		let continentName = json["name"].stringValue
		let regions = json["regions"].dictionaryValue
		
		let loadedRegions = regions.values.flatMap { parseRegion($0) }
		
		return GeoMultiFeature(name: continentName,
													 subFeatures: [],
													 subMultiFeatures: loadedRegions)
	}
	
	fileprivate func parseRegion(_ json: JSON) -> GeoMultiFeature? {
		guard let regionName = json["name"].string else { print("No name in region"); return nil }
		guard let features = json["coordinates"].array else { print("No coordinates in region"); return nil}
		
		var loadedFeatures: [GeoFeature] = []
		
		for featureJson in features {
			let featureType = featureJson.array?.first?.type ?? .unknown
			switch featureType {
			case .array:
				for subFeatureJson in featureJson.arrayValue {
					loadedFeatures.append(parseFeature(subFeatureJson))
				}
			case .dictionary:
				loadedFeatures.append(parseFeature(featureJson))
			case .unknown:
				break
			default:
				print("Malformed feature in \(regionName)")
			}
		}
		return GeoMultiFeature(name: regionName, subFeatures: loadedFeatures, subMultiFeatures: [])
	}
	
	fileprivate func parseFeature(_ json: JSON) -> GeoFeature {
		let vertices : [Vertex]
		if let coordinates = json.array {
			vertices = buildVertices(coordinates)
		} else {
			print("Vertices not found in feature.")
			vertices = []
		}
		return GeoFeature(vertices: vertices)
	}
	
	func buildVertices(_ coords: [JSON]) -> [Vertex] {
		var outVertices: [Vertex] = []
		for c in coords {
			if c.type == .dictionary {
				let v = Vertex(v: (c["lng"].floatValue,
													 c["lat"].floatValue))
				outVertices.append(v)
			} else {
				print("Feature has unexpected internal type: \(c.type)")
			}
		}
		return outVertices
	}
}
