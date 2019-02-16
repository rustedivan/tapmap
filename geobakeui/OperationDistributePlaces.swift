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
	let input: Set<ToolGeoFeature>
	let places: GeoPlaceCollection
	var output: Set<ToolGeoFeature>?
	
	init(regions _regions: Set<ToolGeoFeature>, places _places: GeoPlaceCollection, reporter: @escaping ProgressReport) {
		input = _regions
		places = _places
		report = reporter
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		GeometryCounters.begin()
		
		var remainingPlaces = Set<GeoPlace>(places)
		var updatedFeatures = Set<ToolGeoFeature>()
		let numPlaces = remainingPlaces.count
		for region in input {
			guard let regionTessellation = region.tessellation else {
				print("Missing tessellation in \(region.name)")
				continue
			}
			// Find all places that fit into the region's aabb
			let candidatePlaces = remainingPlaces.filter {
				aabbHitTest(p: CGPoint(x: $0.location.x,
															 y: $0.location.y), aabb: regionTessellation.aabb)
			}
			
			// Perform point-in-triangle tests
			let belongingPlaces = candidatePlaces.filter {
				triangleSoupHitTest(point: CGPoint(x: $0.location.x,
																					 y: $0.location.y),
														inVertices: regionTessellation.vertices,
														inIndices: regionTessellation.indices)
			}
			
			// Recreate the GeoRegion with place set
			let updatedFeature = ToolGeoFeature(level: region.level,
																					polygons: region.polygons,
																					tessellation: region.tessellation,
																					places: belongingPlaces,
																					children: nil,
																					stringProperties: region.stringProperties,
																					valueProperties: region.valueProperties)
			
			// Insert and move on
			updatedFeatures.insert(updatedFeature)
			
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
