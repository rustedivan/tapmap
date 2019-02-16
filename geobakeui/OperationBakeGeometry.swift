//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let countries : Set<ToolGeoFeature>
	let regions : Set<ToolGeoFeature>
	let places : GeoPlaceCollection
	let saveUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(countries countriesToBake: Set<ToolGeoFeature>,
			 region regionsToBake: Set<ToolGeoFeature>,
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
		
		guard let generatedContinents = continentAssemblyJob.output else {
			print("Continent assembly failed")
			return
		}
		
		let continentTessJob = OperationTessellateRegions(generatedContinents, reporter: report, errorReporter: reportError)
		let countryTessJob = OperationTessellateRegions(countries, reporter: report, errorReporter: reportError)
		let regionTessJob = OperationTessellateRegions(regions, reporter: report, errorReporter: reportError)
		
		continentTessJob.addDependency(continentAssemblyJob)
		
		bakeQueue.addOperations([continentTessJob, countryTessJob, regionTessJob],
														waitUntilFinished: true)
		
		guard let continents = continentTessJob.output else {
			print("Continent tessellation failed.")
			return
		}
		guard let countries = countryTessJob.output else {
			print("Country tessellation failed.")
			return
		}
		guard let regions = regionTessJob.output else {
			print("Region tessellation failed.")
			return
		}
		
		let placeDistributionJob = OperationDistributePlaces(regions: regions,
																												 places: places,
																												 reporter: report)
		placeDistributionJob.start()
		
		guard let regionsWithPlaces = placeDistributionJob.output else {
			print("Place distribution into regions failed.")
			return
		}
		
		let fixupJob = OperationFixupHierarchy(continentCollection: continents,
																					 countryCollection: countries,
																					 regionCollection: regionsWithPlaces,
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
