//
//  OperationCleanUpBorders.swift
//  geobakeui
//
//  Created by Ivan Milles on 2018-11-20.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift
import simd

class OperationCleanUpBorders : Operation {
	let report : ProgressReport
	let distanceThresholdSqr = 0.1 * 0.1
	let country : ToolGeoFeature
	let regions : Set<ToolGeoFeature>
	var snappedRegions : Set<ToolGeoFeature>?
	
	init(country _country : ToolGeoFeature, regions _regions : Set<ToolGeoFeature>, reporter: @escaping ProgressReport) {
		report = reporter
		country = _country
		regions = _regions
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		snappedRegions = cleanUpRegionBorders(country: country, regions: regions)
	}
	
	func cleanUpRegionBorders(country: ToolGeoFeature, regions: Set<ToolGeoFeature>) -> Set<ToolGeoFeature> {
		var snappedRegions = Set<ToolGeoFeature>()
		var countryEdges : [(a : Vertex, b : Vertex)] = []
		
		for p in country.polygons {
			for i in 0 ..< p.exteriorRing.vertices.count - 1 {
				let e = (a: p.exteriorRing.vertices[i], b: p.exteriorRing.vertices[i + 1])
				countryEdges.append(e)
			}
		}
		
		for f in regions {
			var snappedRegion = f
			for p in f.polygons {
				var snappedVertices : [Vertex] = []
				for v in p.exteriorRing.vertices {
					var shortestDistanceSqr = Double.greatestFiniteMagnitude
					var shortestSnappedPoint : Vertex?
					for e in countryEdges {
						let (q, d) = snapPointToEdge(p: v, threshold: distanceThresholdSqr, edge: e)
						if d < shortestDistanceSqr {
							shortestDistanceSqr = d
							shortestSnappedPoint = q
						}
					}
					
					if let newPoint = shortestSnappedPoint, shortestDistanceSqr < distanceThresholdSqr {
						snappedVertices.append(newPoint)
					} else {
						snappedVertices.append(v)
					}
				}
				snappedRegion.polygons
			}
		}
		
		return snappedRegions
	}
}
