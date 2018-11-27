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
		
		tessellatedRegions = world.features.compactMap { feature -> GeoRegion? in
				if let tessellation = tessellate(feature) {
						totalTris += tessellation.vertices.count
						report(0.3, "Tesselated \(feature.name) (total \(totalTris) triangles", false)
						return GeoRegion(name: feature.name, admin: feature.admin, geometry: tessellation)
				} else {
						reportError(feature.name, "Tesselation failed")
						return nil
				}
		}
		
		print("Tessellated \(totalTris) triangles")
	}
}
