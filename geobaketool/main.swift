//
//  main.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

let commands = CommandLine.arguments.dropFirst()

switch commands.first {
case "download":
	do {
		try downloadFiles(params: commands.dropFirst())
	} catch GeoBakeDownloadError.timedOut(let host) {
		print("Connection to \(host) timed out after 60 seconds")
	} catch GeoBakeDownloadError.downloadFailed(let key) {
		print("Could not download url referenced in \"\(key)\" in pipeline.json")
	} catch GeoBakeDownloadError.unpackFailed {
		print("Could not unzip the downloaded geometry file archive.")
	}
case "reshape":
	do {
		try reshapeGeometry(params: commands.dropFirst())
	} catch GeoBakeReshapeError.noNodePath {
		print("No mapshaper path set in pipeline.config. Please set user-relative path to mapshaper in \"reshape.mapshaper\".")
	} catch GeoBakeReshapeError.noMapshaperInstall {
		print("No mapshaper install available on PATH. Please run 'npm install -g mapshaper'")
	} catch GeoBakeReshapeError.missingShapeFile(let level) {
		print("Could not find a \"\(level)\"-level shapefile. Please re-download.")
	}
case "bake":
	do {
		try bakeGeometry()
	} catch GeoBakePipelineError.datasetFailed(let dataset) {
		print("Could not bake the \"\(dataset)\" dataset.")
	} catch {
		print("Could not bake geometry: \(error.localizedDescription)")
	}
	
default: print("Usage")
}
