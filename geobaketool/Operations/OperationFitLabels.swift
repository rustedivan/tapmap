//
//  OperationFitLabels.swift
//  geobaketool
//
//  Created by Ivan Milles on 2020-03-03.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class OperationFitLabels : Operation {
	let worldFeatures : Set<ToolGeoFeature>
	
	var output : Set<ToolGeoFeature>
	let report : ProgressReport
	
	init(worldCollection: Set<ToolGeoFeature>,
			 reporter: @escaping ProgressReport) {
		
		worldFeatures = worldCollection
		report = reporter
		
		output = []
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		for feature in worldFeatures {
			let labelCenter = widestScanline(feature.polygons)
			let regionMarker = GeoPlace(location: labelCenter, name: feature.name, kind: .Region, rank: 0)
			let editedPlaces = feature.places!.union([regionMarker])
			let updatedFeature = ToolGeoFeature(level: feature.level,
																					polygons: feature.polygons,
																					tessellation: feature.tessellation,
																					places: editedPlaces,
																					children: feature.children,
																					stringProperties: feature.stringProperties,
																					valueProperties: feature.valueProperties)
			output.insert(updatedFeature)
		}
	}
	
	
	func widestScanline(_ polygons: [Polygon]) -> Vertex {
		return Vertex(0, 0)
	}
}
