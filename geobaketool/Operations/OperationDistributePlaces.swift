//
//  OperationDistributePlaces.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class OperationDistributePlaces : Operation {
	let report : ProgressReport
	let input: ToolGeoFeatureMap
	let places: GeoPlaceCollection
	var output: ToolGeoFeatureMap?
	
	init(regions _regions: ToolGeoFeatureMap, places _places: GeoPlaceCollection, reporter: @escaping ProgressReport) {
		input = _regions
		places = _places
		report = reporter
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		GeometryCounters.begin()
		
		var remainingPlaces = Set<GeoPlace>(places)
		var updatedFeatures = ToolGeoFeatureMap()
		let numPlaces = remainingPlaces.count
		for (key, region) in input {
			guard let regionTessellation = region.tessellations.first else {	// Use best LOD to place POIs
				print("Missing tessellation in \(region.name)")
				continue
			}
			// Find all places that fit into the region's aabb
			let candidatePlaces = remainingPlaces.filter {
				boxContains(regionTessellation.aabb, $0.location)
			}
			
			// Perform point-in-triangle tests
			let belongingPlaces = candidatePlaces.filter {
				triangleSoupHitTest(point: $0.location,
														inVertices: regionTessellation.vertices,
														withIndices: regionTessellation.indices)
			}
			
			var updatedFeature = region
			updatedFeature.places = belongingPlaces
			updatedFeatures[key] = updatedFeature
			
			remainingPlaces = remainingPlaces.subtracting(belongingPlaces)
			
			if (numPlaces > 0) {
				let reportLine = "\(region.name) (\(belongingPlaces.count) places inserted)"
				report(1.0 - (Double(remainingPlaces.count) / Double(numPlaces)), reportLine, false)
			}
		}
		
		GeometryCounters.end()
		
		output = updatedFeatures
		
		report(1.0, "Distributed \(updatedFeatures.count) places of interest.", true)
		print("             - Remaining places:  \(remainingPlaces.count)")
		for place in remainingPlaces {
			print("                 - \(place.name) @ \(place.location)")
		}
	}
}
