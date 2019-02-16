//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let countries : ToolGeoFeatureCollection
	let regions : ToolGeoFeatureCollection
	let places : GeoPlaceCollection
	let saveUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(countries countriesToBake: ToolGeoFeatureCollection,
			 region regionsToBake: ToolGeoFeatureCollection,
			 places placesToBake: GeoPlaceCollection,
			 saveUrl url: URL,
	     reporter: @escaping ProgressReport,
	     errorReporter: @escaping ErrorReport) {
		countries = countriesToBake
		regions = regionsToBake
		places = placesToBake
		saveUrl = url
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		let bakeQueue = OperationQueue()
		bakeQueue.name = "Baking queue"
		
		let continentAssemblyJob = OperationAssembleContinents(countries: countries, reporter: report)
		
		bakeQueue.addOperation(continentAssemblyJob)
		bakeQueue.waitUntilAllOperationsAreFinished()
		
		let continentTessJob = OperationTessellateRegions(continentAssemblyJob.continents!, reporter: report, errorReporter: reportError)
		let countryTessJob = OperationTessellateRegions(countries, reporter: report, errorReporter: reportError)
		let regionTessJob = OperationTessellateRegions(regions, reporter: report, errorReporter: reportError)
		
		continentTessJob.addDependency(continentAssemblyJob)
		
		bakeQueue.addOperations([continentTessJob, countryTessJob, regionTessJob],
														waitUntilFinished: true)
		
		let placeDistributionJob = OperationDistributePlaces(regions: regionTessJob.output,
																												 places: places,
																												 reporter: report)
//		placeDistributionJob.start()
		
		let fixupJob = OperationFixupHierarchy(continentCollection: continentTessJob.output,
																					 countryCollection: countryTessJob.output,
																					 regionCollection: placeDistributionJob.output,
																					 reporter: report)
		fixupJob.start()
		
		// Bake job should only do this conversion and save
		let bakedWorld: GeoWorld? = GeoWorld(name: "temp", children: [])
		guard bakedWorld != nil else {
			print("Failed")
			return
		}
		
		print("\n")
		report(0.1, "Writing world to \(saveUrl.lastPathComponent)...", false)
		
		let encoder = PropertyListEncoder()
		
		if let encoded = try? encoder.encode(bakedWorld) {
			do {
				try encoded.write(to: saveUrl, options: .atomicWrite)
				print("GeoWorld baked to \(ByteCountFormatter().string(fromByteCount: Int64(encoded.count)))")
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
