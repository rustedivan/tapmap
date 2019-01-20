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

fileprivate let sourceDirectory = "source-geometry"

func reshapeGeometry(params: ArraySlice<String>) throws {
	let method = PipelineConfig.shared.reshapeMethod
	let countryStrength = PipelineConfig.shared.countrySimplification
	let regionStrength = PipelineConfig.shared.regionSimplification
	
	let shapeFiles = try FileManager.default.contentsOfDirectory(atPath: sourceDirectory)
																					.filter { $0.hasSuffix(".shp") }
	
	guard let countryFile = (shapeFiles.first { $0.contains("admin_0") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "admin_0")
	}
	guard let regionFile = (shapeFiles.first { $0.contains("admin_1") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "admin_1")
	}
	
	try reshapeFile(input: countryFile, strength: countryStrength, method: method, output: "reshaped-countries.json")
	try reshapeFile(input: regionFile, strength: regionStrength, method: method, output: "reshaped-regions.json")
}

func reshapeFile(input: String, strength: Int, method: String, output: String) throws {
	let nodeInstallPath = try findMapshaperInstall()
	let nodePath = nodeInstallPath.appendingPathComponent("node").path
	let sourceGeoPath = FileManager.default.currentDirectoryPath.appending("/\(sourceDirectory)")
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

func findMapshaperInstall() throws -> URL {
	guard let mapshaperPath = PipelineConfig.shared.nodePath else {
		throw GeoBakeReshapeError.noNodePath
	}
	let mapShaper = URL(fileURLWithPath: mapshaperPath,
											relativeTo: FileManager.default.homeDirectoryForCurrentUser)
	
	if !FileManager.default.fileExists(atPath: "\(mapShaper.path)/mapshaper") {
		throw GeoBakeReshapeError.noMapshaperInstall
	}
	
	return mapShaper
}

