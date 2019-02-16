//
//  bake.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-23.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON

enum GeoBakePipelineError : Error {
	case outputPathMissing
	case outputPathInvalid(path: String)
	case datasetFailed(dataset: String)
}

func reportError(_ feature: String, _ error: String) {
	print("Error: \(feature) failed - \(error)")
}

func bakeGeometry() throws {
	guard let outputUrl = PipelineConfig.shared.outputFilePath else {
		throw GeoBakePipelineError.outputPathMissing
	}
	
	guard outputUrl.isFileURL else {
		throw GeoBakePipelineError.outputPathInvalid(path: outputUrl.path)
	}
	
	// MARK: Load JSON souce files
	print("Loading...")
	
	progressBar(1, "Countries")
	let countryData = try Data(contentsOf: PipelineConfig.shared.reshapedCountriesFilePath)
	progressBar(3, "Countries")
	let countryJson = try JSON(data: countryData, options: .allowFragments)
	
	progressBar(5, "Regions")
	let regionData = try Data(contentsOf: PipelineConfig.shared.reshapedRegionsFilePath)
	progressBar(7, "Regions")
	let regionJson = try JSON(data: regionData, options: .allowFragments)
	
	progressBar(8, "Cities")
	let citiesData = try Data(contentsOf: PipelineConfig.shared.queriedCitiesFilePath)
	progressBar(9, "Cities")
	let citiesJson = try JSON(data: citiesData, options: .allowFragments)
	
	progressBar(10, "√ Loading done\n")
	
	print("\nBuilding geography collections...")
	let countryParser = OperationParseGeoJson(json: countryJson,
																						as: .Country,
																						reporter: reportLoad)
	let regionParser =  OperationParseGeoJson(json: regionJson,
																						as: .Region,
																						reporter: reportLoad)
	let citiesParser =  OperationParseOSMJson(json: citiesJson,
																						kind: .City,
																						reporter: reportLoad)
	
	let workQueue = OperationQueue()
	workQueue.name = "Json load queue"
	workQueue.qualityOfService = .userInitiated
	workQueue.maxConcurrentOperationCount = 1
	workQueue.addOperations([countryParser, regionParser, citiesParser], waitUntilFinished: true)
	
	guard let countries = countryParser.output else {
		throw GeoBakePipelineError.datasetFailed(dataset: "countries")
	}
	guard let regions = regionParser.output else {
		throw GeoBakePipelineError.datasetFailed(dataset: "regions")
	}
	guard let cities = citiesParser.output else {
		throw GeoBakePipelineError.datasetFailed(dataset: "cities")
	}
	
	// MARK: Continent assembly
	let bakeQueue = OperationQueue()
	bakeQueue.name = "Baking queue"
	
	let continentAssemblyJob = OperationAssembleContinents(countries: countries, reporter: reportLoad)
	
	bakeQueue.addOperation(continentAssemblyJob)
	bakeQueue.waitUntilAllOperationsAreFinished()
	
	guard let generatedContinents = continentAssemblyJob.output else {
		print("Continent assembly failed")
		return
	}
	
	// MARK: Tessellate geometry
	
	let continentTessJob = OperationTessellateRegions(generatedContinents, reporter: reportLoad, errorReporter: reportError)
	let countryTessJob = OperationTessellateRegions(countries, reporter: reportLoad, errorReporter: reportError)
	let regionTessJob = OperationTessellateRegions(regions, reporter: reportLoad, errorReporter: reportError)
	
	continentTessJob.addDependency(continentAssemblyJob)
	
	bakeQueue.addOperations([continentTessJob, countryTessJob, regionTessJob],
													waitUntilFinished: true)
	
	guard let tessellatedContinents = continentTessJob.output else {
		print("Continent tessellation failed.")
		return
	}
	guard let tessellatedCountries = countryTessJob.output else {
		print("Country tessellation failed.")
		return
	}
	guard let tessellatedRegions = regionTessJob.output else {
		print("Region tessellation failed.")
		return
	}
	
	// MARK: Distribute places of interest
	let placeDistributionJob = OperationDistributePlaces(regions: tessellatedRegions,
																											 places: cities,
																											 reporter: reportLoad)
	placeDistributionJob.start()
	
	guard let tessellatedRegionsWithPlaces = placeDistributionJob.output else {
		print("Place distribution into regions failed.")
		return
	}
	
	let fixupJob = OperationFixupHierarchy(continentCollection: tessellatedContinents,
																				 countryCollection: tessellatedCountries,
																				 regionCollection: tessellatedRegionsWithPlaces,
																				 reporter: reportLoad)
	fixupJob.start()
	
	guard let world = fixupJob.output else {
		print("World hierarchy failed to connect")
		return
	}
	
	// MARK: Bake and write
	print("\nTessellating geometry...")
	let geoBaker = OperationBakeGeometry(world: world,
																			 saveUrl: outputUrl,
																			 reporter: reportLoad,
																			 errorReporter: reportError)
	workQueue.addOperation(geoBaker)
	workQueue.waitUntilAllOperationsAreFinished()
	
	print("Wrote world-file to \(outputUrl.path)")
}
