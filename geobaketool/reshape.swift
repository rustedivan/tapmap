//
//  reshape.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-20.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

enum GeoBakeReshapeError : Error {
	case noNodePath
	case noMapshaperInstall
	case missingShapeFile(level: String)
}

func reshapeGeometry(params: ArraySlice<String>) throws {
	let method = PipelineConfig.shared.configString("reshape.method") ?? ""
	let countryStrength = PipelineConfig.shared.configValue("reshape.simplify-countries")
	let regionStrength = PipelineConfig.shared.configValue("reshape.simplify-regions")
	
	let shapeFiles = try FileManager.default.contentsOfDirectory(atPath: PipelineConfig.sourceDirectory)
																					.filter { $0.hasSuffix(".shp") }
	
	guard let countryFile = (shapeFiles.first { $0.contains("admin_0") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "admin_0")
	}
	guard let regionFile = (shapeFiles.first { $0.contains("admin_1") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "admin_1")
	}
	guard let citiesFile = (shapeFiles.first { $0.contains("populated_places") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "populated_places")
	}
	
	try reshapeFile(input: countryFile, strength: countryStrength, method: method, output: PipelineConfig.reshapedCountriesFilename)
	try reshapeFile(input: regionFile, strength: regionStrength, method: method, output: PipelineConfig.reshapedRegionsFilename)
	try makeJsonFile(input: citiesFile, output: PipelineConfig.reshapedCitiesFilename)
}

func reshapeFile(input: String, strength: Int, method: String, output: String) throws {
	let nodeInstallPath = try findMapshaperInstall()
	let nodePath = nodeInstallPath.appendingPathComponent("node").path
	let sourceGeoPath = FileManager.default.currentDirectoryPath.appending("/\(PipelineConfig.sourceDirectory)")
	let fileInPath = sourceGeoPath.appending("/\(input)")
	let fileOutPath = sourceGeoPath.appending("/\(output)")

	print("Reshaping \"\(input)\" with \(method) @ \(strength)%...")
	
	let reshapeTask = Process()
	reshapeTask.currentDirectoryURL = nodeInstallPath
	reshapeTask.launchPath = nodePath
	reshapeTask.standardError = Pipe()
	reshapeTask.arguments = ["mapshaper",
													 "-i", fileInPath,
													 "-simplify", method, "keep-shapes", "\(strength)%",
													 "-o", fileOutPath, "format=geojson"]
	reshapeTask.launch()
	reshapeTask.waitUntilExit()
	print("Reshaped \"\(output)\".")
}

func makeJsonFile(input: String, output: String) throws {
	let nodeInstallPath = try findMapshaperInstall()
	let nodePath = nodeInstallPath.appendingPathComponent("node").path
	let sourceGeoPath = FileManager.default.currentDirectoryPath.appending("/\(PipelineConfig.sourceDirectory)")
	let fileInPath = sourceGeoPath.appending("/\(input)")
	let fileOutPath = sourceGeoPath.appending("/\(output)")
	
	print("Transforming \"\(input)\" to GeoJson...")
	
	let reshapeTask = Process()
	reshapeTask.currentDirectoryURL = nodeInstallPath
	reshapeTask.launchPath = nodePath
	reshapeTask.standardError = Pipe()
	reshapeTask.arguments = ["mapshaper",
													 "-i", fileInPath,
													 "-o", fileOutPath, "format=geojson"]
	reshapeTask.launch()
	reshapeTask.waitUntilExit()
	print("Transformed \"\(output)\".")
}

func findMapshaperInstall() throws -> URL {
	guard let mapshaperPath = PipelineConfig.shared.configString("reshape.node") else {
		throw GeoBakeReshapeError.noNodePath
	}
	let mapShaper = URL(fileURLWithPath: mapshaperPath,
											relativeTo: FileManager.default.homeDirectoryForCurrentUser)
	
	if !FileManager.default.fileExists(atPath: "\(mapShaper.path)/mapshaper") {
		throw GeoBakeReshapeError.noMapshaperInstall
	}
	
	return mapShaper
}

