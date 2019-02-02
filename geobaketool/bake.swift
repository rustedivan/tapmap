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
	case outputPathInvalid(path: String)
	case datasetFailed(dataset: String)
}

func reportError(_ feature: String, _ error: String) {
	print("Error: \(feature) failed - \(error)")
}

func bakeGeometry() throws {
	let outputUrl = PipelineConfig.shared.outputFilePath
	guard outputUrl.isFileURL else {
		throw GeoBakePipelineError.outputPathInvalid(path: outputUrl.path)
	}
	
	print("Loading...")
	
	progressBar(1, "Countries")
	let countryData = try Data(contentsOf: PipelineConfig.shared.reshapedCountriesFilePath)
	progressBar(3, "Countries")
	let countryJson = try JSON(data: countryData, options: .allowFragments)
	
	progressBar(5, "Regions")
	let regionData = try Data(contentsOf: PipelineConfig.shared.reshapedRegionsFilePath)
	progressBar(7, "Regions")
	let regionJson = try JSON(data: regionData, options: .allowFragments)
	progressBar(10, "√ Loading done\n")
	
	print("\nBuilding geography collections...")
	let jsonParser = OperationParseGeoJson(countries: countryJson,
																				 regions: regionJson,
																				 reporter: reportLoad)
	
	let workQueue = OperationQueue()
	workQueue.name = "Json load queue"
	workQueue.qualityOfService = .userInitiated
	workQueue.addOperation(jsonParser)
	workQueue.waitUntilAllOperationsAreFinished()
	
	guard let countries = jsonParser.countries else {
		throw GeoBakePipelineError.datasetFailed(dataset: "countries")
	}
	guard let regions = jsonParser.regions else {
		throw GeoBakePipelineError.datasetFailed(dataset: "regions")
	}
	
	print("\nTessellating geometry...")
	let geoBaker = OperationBakeGeometry(countries: countries,
																			 region: regions,
																			 saveUrl: outputUrl,
																			 reporter: reportLoad,
																			 errorReporter: reportError)
	workQueue.addOperation(geoBaker)
	workQueue.waitUntilAllOperationsAreFinished()
	
	print("Wrote world-file to \(outputUrl.path)")
}