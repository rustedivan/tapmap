//
//  OperationFitLabels.swift
//  geobaketool
//
//  Created by Ivan Milles on 2020-03-03.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class OperationFitLabels : Operation {
	let input : ToolGeoFeatureMap
	
	var output : ToolGeoFeatureMap
	let report : ProgressReport
	
	init(features: ToolGeoFeatureMap,
			 reporter: @escaping ProgressReport) {
		
		input = features
		report = reporter
		
		output = [:]
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		for (key, feature) in input {
			let labelCenter = feature.tessellations.first!.visualCenter
			let rank: Int
			switch feature.level {
			case .Continent: rank = 0
			case .Country: rank = 1
			case .Province: rank = 2
			}
			
			let regionMarker = GeoPlace(location: labelCenter, name: feature.name, kind: .Region, rank: rank)
			let editedPlaces = (feature.places ?? Set()).union([regionMarker])
			let updatedFeature = ToolGeoFeature(level: feature.level,
																					polygons: feature.polygons,
																					tessellations: feature.tessellations,
																					places: editedPlaces,
																					children: feature.children,
																					stringProperties: feature.stringProperties,
																					valueProperties: feature.valueProperties)
			output[key] = updatedFeature
			if (output.count > 0) {
				let reportLine = "\(feature.name) labelled"
				report((Double(output.count) / Double(input.count)), reportLine, false)
			}
		}
	}
}


