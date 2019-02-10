//
//  OperationTessellateBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift
import simd

class OperationTessellateRegions : Operation {
	var world : GeoFeatureCollection
	let report : ProgressReport
	let reportError : ErrorReport
	var tessellatedRegions : [GeoRegion]
	var error : Error?
	
	init(_ featuresToTessellate: GeoFeatureCollection, reporter: @escaping ProgressReport, errorReporter: @escaping ErrorReport) {
        world = featuresToTessellate
		report = reporter
		reportError = errorReporter
		tessellatedRegions = []
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var totalTris = 0
		
		let numFeatures = world.features.count
		var doneFeatures = 0
		tessellatedRegions = world.features.compactMap { feature -> GeoRegion? in
			if let tessellation = tessellate(feature) {
				totalTris += tessellation.vertices.count
				doneFeatures += 1
				
				let progress = Double(doneFeatures) / Double(numFeatures)
				let shortName = feature.name.prefix(16)
				report(progress, "\(totalTris) triangles @ \(shortName)", false)
				return GeoRegion(name: feature.name,
												 admin: feature.admin,
												 continent: feature.continent,
												 geometry: tessellation,
												 places: [])
			} else {
				reportError(feature.name, "Tesselation failed")
				return nil
			}
		}
		
		report(1.0, "Tessellated \(totalTris) triangles.", true)
	}
}
