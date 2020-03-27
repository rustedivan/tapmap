//
//  tessellate.swift
//  geobaketool
//
//  Created by Ivan Milles on 2020-03-26.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON

enum GeoTessellatePipelineError : Error {
	case datasetFailed(dataset: String)
	case tessellationFailed(dataset: String)	// $ handle in main loop
	case archivingFailed(dataset: String)			// $ handle in main loop
}

func tessellateGeometry(params: ArraySlice<String>) throws {
	let config = PipelineConfig.shared
	// MARK: Load JSON source files
	print("Loading...")

	progressBar(1, "Countries")
	let countryData = try Data(contentsOf: config.reshapedCountriesFilePath)
	progressBar(3, "Countries")
	let countryJson = try JSON(data: countryData, options: .allowFragments)

	progressBar(5, "Regions")
	let regionData: Data?
	if let regionPath = config.reshapedRegionsFilePath {
		regionData = try Data(contentsOf: regionPath)
	} else { regionData = nil }
	progressBar(7, "Regions")
	let regionJson = regionData != nil ? try JSON(data: regionData!, options: .allowFragments) : JSON({})

	progressBar(10, "√ Loading done\n")

	print("\nBuilding geography collections...")
	let countryParser = OperationParseGeoJson(json: countryJson,
																						as: .Country,
																						reporter: reportLoad)
	let regionParser =  OperationParseGeoJson(json: regionJson,
																						as: .Region,
																						reporter: reportLoad)
	
	let workQueue = OperationQueue()
	workQueue.name = "Json load queue"
	workQueue.qualityOfService = .userInitiated
	workQueue.maxConcurrentOperationCount = 1
	workQueue.addOperations([countryParser, regionParser], waitUntilFinished: true)

	guard let countries = countryParser.output else {
		throw GeoTessellatePipelineError.datasetFailed(dataset: "countries")
	}
	guard let regions = regionParser.output else {
		throw GeoTessellatePipelineError.datasetFailed(dataset: "regions")
	}

	let geometryQueue = OperationQueue()
	geometryQueue.name = "Geometry queue"

	// MARK: Country assembly
	let countryProperties = Dictionary(countries.map { ($0.countryKey, $0.stringProperties) },	// Needed to group newly created countries into continents
																		 uniquingKeysWith: { (first, _) in first })
	let countryAssemblyJob = OperationAssembleGroups(parts: regions, targetLevel: .Country, properties: countryProperties, reporter: reportLoad)
	geometryQueue.addOperation(countryAssemblyJob)
	geometryQueue.waitUntilAllOperationsAreFinished()
	let generatedCountries = countryAssemblyJob.output!

	// MARK: Continent assembly
	let continentAssemblyJob = OperationAssembleGroups(parts: generatedCountries, targetLevel: .Continent, properties: [:], reporter: reportLoad)
	geometryQueue.addOperation(continentAssemblyJob)
	geometryQueue.waitUntilAllOperationsAreFinished()
	let generatedContinents = continentAssemblyJob.output!

	// MARK: Tessellate geometry
	let continentTessJob = OperationTessellateRegions(generatedContinents, reporter: reportLoad, errorReporter: reportError)
	let countryTessJob = OperationTessellateRegions(generatedCountries, reporter: reportLoad, errorReporter: reportError)
	let regionTessJob = OperationTessellateRegions(regions, reporter: reportLoad, errorReporter: reportError)

	continentTessJob.addDependency(continentAssemblyJob)

	geometryQueue.addOperations([continentTessJob, countryTessJob, regionTessJob],
													waitUntilFinished: true)

	guard let tessellatedContinents = continentTessJob.output else {
		throw GeoTessellatePipelineError.tessellationFailed(dataset: "continents")
	}
	guard let tessellatedCountries = countryTessJob.output else {
		throw GeoTessellatePipelineError.tessellationFailed(dataset: "countries")
	}
	guard let tessellatedRegions = regionTessJob.output else {
		throw GeoTessellatePipelineError.tessellationFailed(dataset: "regions")
	}
	let archives = [
		(tessellatedRegions, "regions"),
		(tessellatedCountries, "countries"),
		(tessellatedContinents, "continents")]
	try _ = archives.map(archiveTessellations)
}

func archiveTessellations(_ tessellations: Set<ToolGeoFeature>, into output: String) throws {
	let fileOutUrl = config.sourceGeometryUrl.appendingPathComponent("\(output).tessarchive")
	do {
		let archive = try PropertyListEncoder().encode(tessellations)
		try archive.write(to: fileOutUrl)
		let fileSize = Int64(archive.count)
		print("Tessellation archive \"output\" baked to \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
	} catch (let error) {
		print(error.localizedDescription)
		throw GeoTessellatePipelineError.archivingFailed(dataset: output)
	}
}

