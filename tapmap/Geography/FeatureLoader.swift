//
//  FeatureLoader.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON

func loadFeatureJson() -> GeoWorld {
	let path = Bundle.main.path(forResource: "features", ofType: "json")
	let jsonData = NSData(contentsOfFile:path!)
	let json = JSON(data: jsonData! as Data)
	
	var loadedContinents: [GeoContinent] = []
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
			                       features: loadedFeatures)
			loadedRegions.append(region)
		}
		
		let loadedContinent = GeoContinent(name: continentName,
		                                   vertices: continentVertices,
		                                   regions: loadedRegions)
		loadedContinents.append(loadedContinent)
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

