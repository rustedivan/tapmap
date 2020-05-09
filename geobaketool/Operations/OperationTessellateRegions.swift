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
	let input : ToolGeoFeatureMap
	var output : ToolGeoFeatureMap?
	let report : ProgressReport
	let reportError : ErrorReport
	
	init(_ featuresToTessellate: ToolGeoFeatureMap, reporter: @escaping ProgressReport, errorReporter: @escaping ErrorReport) {
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
		let tessellationResult = input.values.compactMap { (feature: ToolGeoFeature) -> ToolGeoFeature? in
			if let tessellation = tessellate(feature) {
				var out = feature
				totalTris += tessellation.vertices.count
				doneFeatures += 1
				
				let progress = Double(doneFeatures) / Double(numFeatures)
				report(progress, "\(totalTris) triangles @ \(out.name.prefix(16))", false)
				out.tessellations = [tessellation]
				return out
			} else {
				reportError(feature.name, "Tesselation failed")
				return nil
			}
		}
		
		output = Dictionary(uniqueKeysWithValues: tessellationResult.map { ($0.geographyId.hashed, $0) })
		
		report(1.0, "Tessellated \(totalTris) triangles.", true)
	}
}
