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
	guard let tessellationPaths = try? FileManager.default.contentsOfDirectory(at: config.sourceGeometryUrl,
			includingPropertiesForKeys: nil,
			options: [])
		.filter({ $0.pathExtension == "json" && $0.absoluteString.contains("reshaped") }) else {
			throw GeoTessellatePipelineError.datasetFailed(dataset: "reshaped files")
	}
	
	let reshapedCountryPaths = tessellationPaths.filter { $0.absoluteString.contains(config.reshapedCountriesFilename) }
	let reshapedRegionPaths = tessellationPaths.filter { $0.absoluteString.contains(config.reshapedRegionsFilename!) }
	let filepaths = Array(zip(reshapedCountryPaths, reshapedRegionPaths))
	let lodLevels = Array(0..<filepaths.underestimatedCount)
	let lodJobs = zip(lodLevels, filepaths)
	
	print("Tessellating geometries (\(lodLevels.count) LOD levels found")
	for lod in lodJobs {
		let lodLevel = lod.0
		let countryFile = lod.1.0
		let regionFile = lod.1.1
		
		// MARK: Load JSON source files
		print("Building geometry for LOD level \(lodLevel)...")
		let countryParser = try shapefileParser(url: countryFile, type: .Country)
		let regionParser =  try shapefileParser(url: regionFile, type: .Region)
		
		let workQueue = OperationQueue()
		workQueue.name = "Json load queue"
		workQueue.qualityOfService = .userInitiated
		workQueue.maxConcurrentOperationCount = 1
		workQueue.addOperations([countryParser, regionParser], waitUntilFinished: true)

		guard let loadedCountries = countryParser.output else {
			throw GeoTessellatePipelineError.datasetFailed(dataset: "countries")
		}
		guard let loadedRegions = regionParser.output else {
			throw GeoTessellatePipelineError.datasetFailed(dataset: "regions")
		}

		// MARK: Country and continent assembly
		let countryProperties = Dictionary(loadedCountries.map { ($0.countryKey, $0.stringProperties) },	// Needed to group newly created countries into continents
																			 uniquingKeysWith: { (first, _) in first })
		let countries = assembleGroups(parts: loadedRegions, type: .Country, properties: countryProperties)
		let continents = assembleGroups(parts: countries, type: .Continent, properties: [:])

		// MARK: Tessellate geometry
		let (tessContinents, tessCountries, tessRegions) = try tessellateLodLevel(continents: continents,
																																							countries: countries,
																																							regions: loadedRegions)
		
		let archives = [
			(tessRegions, "regions", lodLevel),
			(tessCountries, "countries", lodLevel),
			(tessContinents, "continents", lodLevel)]
		try _ = archives.map(archiveTessellations)
	}
}

func shapefileParser(url: URL, type: ToolGeoFeature.Level) throws -> OperationParseGeoJson {
	let data = try Data(contentsOf: url)
	let json = try JSON(data: data, options: .allowFragments)
	let parser = OperationParseGeoJson(json: json,
																		 as: type,
																		 reporter: reportLoad)
	return parser
}

func assembleGroups(parts: Set<ToolGeoFeature>,
										type: ToolGeoFeature.Level,
										properties: [String : ToolGeoFeature.GeoStringProperties]) -> Set<ToolGeoFeature> {
	let assemblyJob = OperationAssembleGroups(parts: parts, targetLevel: type, properties: properties, reporter: reportLoad)
	assemblyJob.start()
	return assemblyJob.output!
}

func tessellateLodLevel(continents: Set<ToolGeoFeature>,
												countries: Set<ToolGeoFeature>,
												regions: Set<ToolGeoFeature>) throws -> (Set<ToolGeoFeature>, Set<ToolGeoFeature>, Set<ToolGeoFeature>) {
	let geometryQueue = OperationQueue()
	geometryQueue.name = "Geometry queue"
	
	let continentTessJob = OperationTessellateRegions(continents, reporter: reportLoad, errorReporter: reportError)
	let countryTessJob = OperationTessellateRegions(countries, reporter: reportLoad, errorReporter: reportError)
	let regionTessJob = OperationTessellateRegions(regions, reporter: reportLoad, errorReporter: reportError)
	geometryQueue.addOperations([continentTessJob, countryTessJob, regionTessJob], waitUntilFinished: true)

	guard let tessellatedContinents = continentTessJob.output else {
		throw GeoTessellatePipelineError.tessellationFailed(dataset: "continents")
	}
	guard let tessellatedCountries = countryTessJob.output else {
		throw GeoTessellatePipelineError.tessellationFailed(dataset: "countries")
	}
	guard let tessellatedRegions = regionTessJob.output else {
		throw GeoTessellatePipelineError.tessellationFailed(dataset: "regions")
	}
	
	return (tessellatedContinents, tessellatedCountries, tessellatedRegions)
}

func archiveTessellations(_ tessellations: Set<ToolGeoFeature>, into output: String, lod: Int) throws {
	let fileOutUrl = PipelineConfig.shared.sourceGeometryUrl.appendingPathComponent("\(output)-\(lod).tessarchive")
	do {
		let archive = try PropertyListEncoder().encode(tessellations)
		try archive.write(to: fileOutUrl)
		let fileSize = Int64(archive.count)
		print("Tessellation archive \(output) @ LOD\(lod) baked to \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
	} catch (let error) {
		print(error.localizedDescription)
		throw GeoTessellatePipelineError.archivingFailed(dataset: output)
	}
}

