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
	var resultWorld : GeoWorld?
	
	init(_ geoJson: JSON, reporter: @escaping ProgressReport) {
		json = geoJson
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		var loadedContinents: [GeoContinent] = []
		let numContinents = json.dictionaryValue.keys.count

		for continentJson in json.dictionaryValue.values {
			let loadedContinent = parseContinent(continentJson)
			loadedContinents.append(loadedContinent)

			report(Double(loadedContinents.count) / Double(numContinents), loadedContinent.name, false)
		}
	}
	
	func parseContinent(_ json: JSON) -> GeoContinent {
		let continentName = json["name"].stringValue
		let regions = json["regions"]
		var continentVertices: [Vertex] = []

		var loadedRegions: [GeoRegion] = []
		for regionJson in regions.dictionaryValue.values {
			let (loadedRegion, regionVertices) = parseRegion(regionJson)
			
			loadedRegions.append(loadedRegion)
			continentVertices.append(contentsOf: regionVertices)
		}

		return GeoContinent(name: continentName, borderVertices: [], regions: [])
	}
	
	func parseRegion(_ json: JSON) -> (GeoRegion, [Vertex]) {
		let features = json["coordinates"].arrayValue
		let regionName = json["name"].stringValue
		
		var loadedFeatures: [GeoFeature] = []
		for featureJson in features {
			guard let firstPart = featureJson.array?.first else { print("Skipping feature."); continue }
		
			switch firstPart.type {
			case .dictionary:
				let (loadedFeature, featureVertices) = parseFeature(featureJson)
				loadedFeatures.append(loadedFeature)
			case .array:
				for subFeature in featureJson.arrayValue {
					let (subFeature, subFeatureVertices) = parseFeature(subFeature)
					loadedFeatures.append(subFeature)
				}
			default:
				print("Feature array contains \(firstPart.type)")
			}
		}
		
		return (GeoRegion(name: regionName,
											color: GeoColors.randomColor(),
											features: loadedFeatures,
											tessellation: nil), [])
	}
	
	func parseFeature(_ json: JSON) -> (GeoFeature, [Vertex]) {
		let partVertices = buildVertices(json.arrayValue)
		
		// $$$ TEMP: zero offset
		let range = VertexRange(UInt32(0), UInt32(partVertices.count))
		return (GeoFeature(vertexRange: range), partVertices)
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
