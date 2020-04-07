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
	case tessellationMissing
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
		citiesData = try Data(contentsOf: citiesPath.appendingPathExtension("json"))
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

	let baseLod = 0
	print("Unarchiving tessellations at LOD\(baseLod)")
	let tessellatedRegions = try unarchiveTessellations(from: "regions", lod: baseLod)
	let tessellatedCountries = try unarchiveTessellations(from: "countries", lod: baseLod)
	let tessellatedContinents = try unarchiveTessellations(from: "continents", lod: baseLod)
	
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
	
	// MARK: Add LOD geometry
	// Load the remaining LODs for their tessellations only
	guard let tessellationPaths = try? FileManager.default.contentsOfDirectory(at: PipelineConfig.shared.sourceGeometryUrl, includingPropertiesForKeys: nil)
		.filter({ $0.pathExtension == "tessarchive" }) else {
			throw GeoBakePipelineError.tessellationMissing
	}
	guard !tessellationPaths.isEmpty else {
		throw GeoBakePipelineError.tessellationMissing
	}
	
	var loddedContinents = labelledContinents
	var loddedCountries = labelledCountries
	var loddedRegions = labelledRegions
	let lodCount = tessellationPaths.count / 3 // Round down, only load LODs for which we have all data
	for geometryLod in 1..<lodCount {
		let lodRegions = try unarchiveTessellations(from: "regions", lod: geometryLod)
		let lodCountries = try unarchiveTessellations(from: "countries", lod: geometryLod)
		let lodContinents = try unarchiveTessellations(from: "continents", lod: geometryLod)
		
		loddedContinents = addLodLevels(to: loddedContinents, from: lodContinents)
		loddedCountries = addLodLevels(to: loddedCountries, from: lodCountries)
		loddedRegions = addLodLevels(to: loddedRegions, from: lodRegions)
	}
	
	let fixupJob = OperationFixupHierarchy(continentCollection: loddedContinents,
																				 countryCollection: loddedCountries,
																				 regionCollection: loddedRegions,
																				 reporter: reportLoad)
	fixupJob.start()
	
	guard let world = fixupJob.output else {
		print("World hierarchy failed to connect")
		return
	}
	
	// MARK: Bake and write
	print("\nTessellating geometry...")
	let geoBaker = OperationBakeGeometry(world: world,
																			 lodCount: lodCount,
																			 saveUrl: outputUrl,
																			 reporter: reportLoad,
																			 errorReporter: reportError)
	bakeQueue.addOperation(geoBaker)
	bakeQueue.waitUntilAllOperationsAreFinished()
	
	print("Wrote world-file to \(outputUrl.path)")
}

func addLodLevels(to targets: Set<ToolGeoFeature>, from sources: Set<ToolGeoFeature>) -> Set<ToolGeoFeature> {
	var out = Set<ToolGeoFeature>()
	for var target in targets {
		let regionHash = target.geographyId
		guard let lodRegionIdx = sources.firstIndex(where: { $0.geographyId.hashed == regionHash.hashed }) else {
			print("Could not find LOD match for \(target.name)")
			continue
		}

		let lodTessellation = sources[lodRegionIdx].tessellations.first!
		target.tessellations.append(lodTessellation)
		out.insert(target)
	}
	return out
}

func unarchiveTessellations(from input: String, lod: Int) throws -> Set<ToolGeoFeature> {
	print("Unarchiving tessellations for \(input) @ LOD\(lod)")
	let fileInUrl = PipelineConfig.shared.sourceGeometryUrl.appendingPathComponent("\(input)-\(lod).tessarchive")
	let archive = NSData(contentsOf: fileInUrl)!
	let tessellations = try PropertyListDecoder().decode(Set<ToolGeoFeature>.self, from: archive as Data)
	return tessellations
}
