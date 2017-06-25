//
//  FeatureLoader.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON
import AppKit

typealias ProgressReport = (Double, String, Bool) -> ()
typealias ErrorReport = (String, String) -> ()

func loadJsonFile(url: URL) -> JSON {
	let jsonData = NSData(contentsOf: url)
	return JSON(data: jsonData! as Data)
}

func parseFeatureJson(_ json: JSON, progressReporter: ProgressReport) -> GeoWorld {
	var loadedContinents: [GeoContinent] = []
	let numContinents = json.dictionaryValue.keys.count
	
	for continentJson in json.dictionaryValue.values {
		let regions = continentJson["regions"]
		let continentName = continentJson["name"].stringValue
		var continentVertices: [Vertex] = []
		
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
		progressReporter(Double(loadedContinents.count) / Double(numContinents), continentName, false)
	}
	
	return GeoWorld(continents: loadedContinents)
}

func buildVertices(_ coords: [JSON]) -> [Vertex] {
	var outVertices: [Vertex] = []
	for c in coords {
		let v = Vertex(v: (c["lng"].floatValue,
		                   c["lat"].floatValue))
		outVertices.append(v)
	}
	return outVertices
}

