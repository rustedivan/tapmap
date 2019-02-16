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
	let input : Set<ToolGeoFeature>
	var output : Set<ToolGeoFeature>?
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(_ featuresToTessellate: Set<ToolGeoFeature>, reporter: @escaping ProgressReport, errorReporter: @escaping ErrorReport) {
		input = featuresToTessellate
		output = input
		report = reporter
		reportError = errorReporter
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var totalTris = 0
		
		let numFeatures = input.count
		var doneFeatures = 0
		let tessellationResult = input.compactMap { feature -> ToolGeoFeature? in
			if let tessellation = tessellate(feature) {
				totalTris += tessellation.vertices.count
				doneFeatures += 1
				
				let progress = Double(doneFeatures) / Double(numFeatures)
				let shortName = feature.name.prefix(16)
				report(progress, "\(totalTris) triangles @ \(shortName)", false)
				return ToolGeoFeature(level: feature.level,
															polygons: feature.polygons,
															tessellation: tessellation,
															places: nil,
															children: nil,
															stringProperties: feature.stringProperties,
															valueProperties: feature.valueProperties)
			} else {
				reportError(feature.name, "Tesselation failed")
				return nil
			}
		}
		
		output = Set(tessellationResult)
		
		report(1.0, "Tessellated \(totalTris) triangles.", true)
	}
}
