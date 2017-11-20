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
			let regions = continentJson["regions"]
			let continentName = continentJson["name"].stringValue
			var continentVertices: [Vertex] = []
		
			guard !isCancelled else { print("Cancelled load"); return }
			
			var loadedRegions: [GeoRegion] = []
			for regionJson in regions.dictionaryValue.values {
				let features = regionJson["coordinates"].arrayValue
				let regionName = regionJson["name"].stringValue
				
				var loadedFeatures: [GeoFeature] = []
				for featureJson in features {
					guard !featureJson.arrayValue.isEmpty else { continue	}
					
					let partVertices = buildVertices(featureJson.arrayValue)
					
					let range = VertexRange(start: UInt32(continentVertices.count),
					                        count: UInt32(partVertices.count))
					
					let feature = GeoFeature(vertexRange: range)
					loadedFeatures.append(feature)
					
					continentVertices.append(contentsOf: partVertices)
				}
				
				let region = GeoRegion(name: regionName,
				                       color: GeoColors.randomColor(),
				                       features: loadedFeatures,
				                       tessellation: nil)
				loadedRegions.append(region)
			}
			
			let loadedContinent = GeoContinent(name: continentName,
			                                   borderVertices: continentVertices,
			                                   regions: loadedRegions)
			loadedContinents.append(loadedContinent)
			report(Double(loadedContinents.count) / Double(numContinents), continentName, false)
		}
		
		resultWorld = GeoWorld(continents: loadedContinents)
	}
	
	func buildVertices(_ coords: [JSON]) -> [Vertex] {
		var outVertices: [Vertex] = []
		for c in coords {
			if c.type == .array {
				let subVertices = buildVertices(c.arrayValue)
				outVertices.append(contentsOf: subVertices)
			} else if c.type == .dictionary {
				let v = Vertex(v: (c["lng"].floatValue,
													 c["lat"].floatValue))
				outVertices.append(v)
			} else {
				print("Feature has unexpected internal type")
			}
		}
		return outVertices
	}
}
