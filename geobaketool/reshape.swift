//
//  reshape.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-20.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

enum GeoReshapePipelineError : Error {
	case noNodePath
	case noMapshaperInstall
	case missingShapeFile(level: String)
	case noShapeFiles
}

func reshapeGeometry(params: ArraySlice<String>) throws {
	let config = PipelineConfig.shared
	let method = config.configString("reshape.method") ?? ""
	let simplificationStrengths = config.configValues("reshape.lodlevels") ?? [5]
	let lodLevels = simplificationStrengths.sorted(by: >)	// Low lod levels = higher quality
	
	guard let shapeFiles = try? FileManager.default.contentsOfDirectory(at: PipelineConfig.shared.sourceGeometryUrl,
			includingPropertiesForKeys: nil)
		.filter({ $0.pathExtension == "shp" }) else {
			throw GeoReshapePipelineError.noShapeFiles
	}
	guard !shapeFiles.isEmpty else {
		throw GeoReshapePipelineError.noShapeFiles
	}
	guard let countryFile = (shapeFiles.first { $0.absoluteString.contains("admin_0") }) else {
		throw GeoReshapePipelineError.missingShapeFile(level: "admin_0")
	}
	guard let regionFile = (shapeFiles.first { $0.absoluteString.contains("admin_1") }) else {
		throw GeoReshapePipelineError.missingShapeFile(level: "admin_1")
	}
	
	// Reshape into each LOD level
	for (lod, s) in lodLevels.enumerated() {
		try reshapeFile(input: countryFile, strength: s, method: method, output: "\(config.reshapedCountriesFilename)-\(lod).json")
		try reshapeFile(input: regionFile, strength: s, method: method, output: "\(config.reshapedRegionsFilename!)-\(lod).json")
	}
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
		throw GeoReshapePipelineError.noNodePath
	}
	let mapShaper = URL(fileURLWithPath: mapshaperPath,
											relativeTo: FileManager.default.homeDirectoryForCurrentUser)
	
	if !FileManager.default.fileExists(atPath: "\(mapShaper.path)/mapshaper") {
		throw GeoReshapePipelineError.noMapshaperInstall
	}
	
	return mapShaper
}

