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
	
	let bakeQueue = OperationQueue()
	bakeQueue.name = "Baking queue"
	
	// MARK: Distribute places of interest
	progressBar(1, "Cities")
	let citiesData: Data?
	if let citiesPath = PipelineConfig.shared.queriedCitiesFilePath {
		citiesData = try Data(contentsOf: citiesPath)
	} else { citiesData = nil }
	progressBar(2, "Cities")
	let citiesJson = citiesData != nil ? try JSON(data: citiesData!, options: .allowFragments) : JSON({})

	let citiesParser =  OperationParseOSMJson(json: citiesJson,
																						kind: .City,
																						reporter: reportLoad)
	bakeQueue.addOperations([citiesParser], waitUntilFinished: true)
	
	guard let cities = citiesParser.output else {
		throw GeoTessellatePipelineError.datasetFailed(dataset: "cities")
	}

	let tessellatedRegions = try unarchiveTessellations(from: "regions")
	let tessellatedCountries = try unarchiveTessellations(from: "countries")
	let tessellatedContinents = try unarchiveTessellations(from: "continents")
	
	let placeDistributionJob = OperationDistributePlaces(regions: tessellatedRegions,
																											 places: cities,
																											 reporter: reportLoad)
	placeDistributionJob.start()
	
	guard let tessellatedRegionsWithPlaces = placeDistributionJob.output else {
		print("Place distribution into regions failed.")
		return
	}
	
	// MARK: Label regions
	let continentLabelJob = OperationFitLabels(features: tessellatedContinents, reporter: reportLoad)
	let countryLabelJob = OperationFitLabels(features: tessellatedCountries, reporter: reportLoad)
	let regionLabelJob = OperationFitLabels(features: tessellatedRegionsWithPlaces, reporter: reportLoad)
	
	bakeQueue.addOperations([continentLabelJob, countryLabelJob, regionLabelJob],
													waitUntilFinished: true)
	
	let labelledContinents = continentLabelJob.output
	let labelledCountries = countryLabelJob.output
	let labelledRegions = regionLabelJob.output
	
	let fixupJob = OperationFixupHierarchy(continentCollection: labelledContinents,
																				 countryCollection: labelledCountries,
																				 regionCollection: labelledRegions,
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
	bakeQueue.addOperation(geoBaker)
	bakeQueue.waitUntilAllOperationsAreFinished()
	
	print("Wrote world-file to \(outputUrl.path)")
}

func unarchiveTessellations(from input: String) throws -> Set<ToolGeoFeature> {
	let fileInUrl = PipelineConfig.shared.sourceGeometryUrl.appendingPathComponent("\(input).tessarchive")
	let archive = NSData(contentsOf: fileInUrl)!
	let tessellations = try PropertyListDecoder().decode(Set<ToolGeoFeature>.self, from: archive as Data)
	return tessellations
}
