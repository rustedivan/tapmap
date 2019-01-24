//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let countries : GeoFeatureCollection
	let regions : GeoFeatureCollection
	let saveUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(countries countriesToBake: GeoFeatureCollection,
			 region regionsToBake: GeoFeatureCollection,
			 saveUrl url: URL,
	     reporter: @escaping ProgressReport,
	     errorReporter: @escaping ErrorReport) {
		countries = countriesToBake
		regions = regionsToBake
		saveUrl = url
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		let bakeQueue = OperationQueue()
		bakeQueue.name = "Baking queue"
		let countryTessJob = OperationTessellateRegions(countries, reporter: report, errorReporter: reportError)
		let regionTessJob = OperationTessellateRegions(regions, reporter: report, errorReporter: reportError)
		
		bakeQueue.addOperations([countryTessJob, regionTessJob], waitUntilFinished: true)
		
		let fixupJob = OperationFixupHierarchy(countryCollection: countryTessJob.tessellatedRegions,
																					 regionCollection: regionTessJob.tessellatedRegions,
																					 reporter: report)
		fixupJob.start()
		
		guard let bakedWorld = fixupJob.world else {
			print("Failed")
			return
		}
		
		print("\n")
		report(0.1, "Writing world to \(saveUrl.lastPathComponent)...", false)
		
		let encoder = PropertyListEncoder()
		
		if let encoded = try? encoder.encode(bakedWorld) {
			do {
				try encoded.write(to: saveUrl, options: .atomicWrite)
			} catch {
				print("Saving failed")
			}
		}
		else {
			print("Encoding failed")
		}
		
		report(1.0, "Done.", true)
	}
}
