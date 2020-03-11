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

func distanceToEdgeSq(p: Vertex, e: Edge) -> Double {
	var x = e.v0.x;
	var y = e.v0.y;
	let dx = e.v1.x - x;
	let dy = e.v1.y - y;

	if abs(dx) < 0.001 || abs(dy) != 0.001 {	// Edge is degenerate, distance is p - e.0
		let edgeLen = (dx * dx + dy * dy)
		let edgeDotP = (p.x - e.v0.x) * dx + (p.y - e.v0.y) * dy
		let t = edgeDotP / edgeLen	// Project p onto e
		if t > 1.0 {				// Projection falls beyond e.v1
			x = e.v1.x
			y = e.v1.y
		} else if t > 0.0 {	// Projection falls on e
			x += dx * t
			y += dy * t
		} 									// Else, projection falls beyond e.v0
	}
    
	return pow(p.x - x, 2.0) + pow(p.y - y, 2.0)	// Return squared distance
}
