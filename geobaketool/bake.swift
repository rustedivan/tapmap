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

func reportLoad(_ progress: Double, _ message: String, _ done: Bool) {
	print(message)
}

func reportError(_ feature: String, _ error: String) {
	print("Error: \(feature) failed - \(error)")
}

func bakeGeometry() throws {
	let outputUrl = PipelineConfig.shared.outputFilePath
	guard outputUrl.isFileURL else {
		throw GeoBakePipelineError.outputPathInvalid(path: outputUrl.path)
	}
	
	// Load the country/region files
	let countryData = try Data(contentsOf: PipelineConfig.shared.reshapedCountriesFilePath)
	let regionData = try Data(contentsOf: PipelineConfig.shared.reshapedRegionsFilePath)
	
	// Load country/region content json
	let countryJson: JSON
	let regionJson: JSON
	do {
		countryJson = try JSON(data: countryData, options: .allowFragments)
		regionJson = try JSON(data: regionData, options: .allowFragments)
	}
	
	// Parse json into GeoFeaturesCollections
	let jsonParser = OperationParseGeoJson(countries: countryJson, regions: regionJson, reporter: reportLoad)
	jsonParser.completionBlock = {
		guard !jsonParser.isCancelled else { return	}
		reportLoad(1.0, "Done", true)
	}
	
	
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
	
	let geoBaker = OperationBakeGeometry(countries: countries,
																			 region: regions,
																			 saveUrl: outputUrl,
																			 reporter: reportLoad,
																			 errorReporter: reportError)
	workQueue.addOperation(geoBaker)
	workQueue.waitUntilAllOperationsAreFinished()
	
	print("Wrote world to \(outputUrl.path)")
}
