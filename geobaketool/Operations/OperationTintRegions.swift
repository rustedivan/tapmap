//
//  OperationTintRegions.swift
//  geobaketool
//
//  Created by Ivan Milles on 2020-10-31.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class OperationTintRegions : Operation {
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
		
		for (key, feature) in input {	// $ Search for "(key," to find all lens fixes
			let u = Float((feature.tessellations[0].visualCenter.x + 180.0) / 360.0)
			let v = Float((feature.tessellations[0].visualCenter.y + 90.0) / 180.0)
			let pickedColor = GeoColor(r: 0.0, g: u, b: v)
			
			let tintedTessellations = feature.tessellations.map {
				return GeoTessellation(vertices: $0.vertices,
															 indices: $0.indices,
															 contours: $0.contours,
															 aabb: $0.aabb,
															 visualCenter: $0.visualCenter,
															 color: pickedColor)
			}
			
			let updatedFeature = ToolGeoFeature(level: feature.level,
																				polygons: feature.polygons,
																				tessellations: tintedTessellations,
																				places: feature.places,
																				children: feature.children,
																				stringProperties: feature.stringProperties,
																				valueProperties: feature.valueProperties)
			output[key] = updatedFeature
			if (output.count > 0) {
				let reportLine = "\(feature.name) colored"
				report((Double(output.count) / Double(input.count)), reportLine, false)
			}
		}
	}
}


