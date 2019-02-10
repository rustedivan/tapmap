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
	let regions: Set<GeoRegion>
	let places: GeoPlaceCollection
	var regionsWithPlaces: Set<GeoRegion>?
	
	init(regions _regions: Set<GeoRegion>, places _places: GeoPlaceCollection, reporter: @escaping ProgressReport) {
		regions = _regions
		places = _places
		report = reporter
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		GeometryCounters.begin()
		
		var remainingPlaces = Set<GeoPlace>(places)
		var updatedRegions = Set<GeoRegion>()
		let numPlaces = remainingPlaces.count
		for region in regions {
			
			// Find all places that fit into the region's aabb
			let candidatePlaces = remainingPlaces.filter {
				aabbHitTest(p: CGPoint(x: $0.location.x,
															 y: $0.location.y), in: region)
			}
			
			// Perform point-in-triangle tests
			let belongingPlaces = candidatePlaces.filter {
				triangleSoupHitTest(point: CGPoint(x: $0.location.x,
																					 y: $0.location.y),
														inVertices: region.geometry.vertices,
														inIndices: region.geometry.indices)
			}
			
			// Recreate the GeoRegion with place set
			let updatedRegion = GeoRegion(name: region.name,
																		admin: region.admin,
																		continent: region.continent,
																		geometry: region.geometry,
																		places: Set(belongingPlaces))
			
			// Insert and move on
			updatedRegions.insert(updatedRegion)
			
			remainingPlaces = remainingPlaces.subtracting(belongingPlaces)
			
			if (numPlaces > 0) {
				let reportLine = "\(region.name) (\(belongingPlaces.count) places inserted)"
				report(1.0 - (Double(remainingPlaces.count) / Double(numPlaces)), reportLine, false)
			}
		}
		
		GeometryCounters.end()
		
		report(1.0, "Distributed \(places.count - remainingPlaces.count) places of interest.", true)
		print("             - Remaining places:  \(remainingPlaces.count)")
		for place in remainingPlaces {
			print("                 - \(place.name) @ \(place.location)")
		}
	}
}
