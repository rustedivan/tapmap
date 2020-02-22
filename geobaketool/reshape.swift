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
	case noShapeFiles
}

func reshapeGeometry(params: ArraySlice<String>) throws {
	let method = PipelineConfig.shared.configString("reshape.method") ?? ""
	let countryStrength = PipelineConfig.shared.configValue("reshape.simplify-countries")
	let regionStrength = PipelineConfig.shared.configValue("reshape.simplify-regions")
	
	guard let shapeFiles = try? FileManager.default.contentsOfDirectory(at: PipelineConfig.shared.sourceGeometryUrl,
			includingPropertiesForKeys: nil,
			options: [])
		.filter({ $0.pathExtension == "shp" }) else {
			throw GeoBakeReshapeError.noShapeFiles
	}
	guard !shapeFiles.isEmpty else {
		throw GeoBakeReshapeError.noShapeFiles
	}
	guard let countryFile = (shapeFiles.first { $0.absoluteString.contains("admin_0") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "admin_0")
	}
	guard let regionFile = (shapeFiles.first { $0.absoluteString.contains("admin_1") }) else {
		throw GeoBakeReshapeError.missingShapeFile(level: "admin_1")
	}
	
	try reshapeFile(input: countryFile, strength: countryStrength, method: method, output: PipelineConfig.shared.reshapedCountriesFilename)
	try reshapeFile(input: regionFile, strength: regionStrength, method: method, output: PipelineConfig.shared.reshapedRegionsFilename!)
}

func reshapeFile(input: URL, strength: Int, method: String, output: String) throws {
	let nodeInstallPath = try findMapshaperInstall()
	let nodePath = nodeInstallPath.appendingPathComponent("node").path
	let fileOutUrl = PipelineConfig.shared.sourceGeometryUrl
		.appendingPathComponent("\(output)")

	print("Reshaping \"\(input.lastPathComponent)\" with \(method) @ \(strength)%...")
	let reshapeTask = Process()
	reshapeTask.currentDirectoryURL = nodeInstallPath
	reshapeTask.launchPath = nodePath
	reshapeTask.standardError = Pipe()
	reshapeTask.arguments = ["mapshaper",
													 "-i", input.path,
													 "-clean",
													 "-simplify", method, "keep-shapes", "\(strength)%",
													 "-o", fileOutUrl.path, "format=geojson"]
	reshapeTask.launch()
	reshapeTask.waitUntilExit()
	print("Reshaped \"\(output)\".")
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

