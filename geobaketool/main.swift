//
//  main.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

let commands = CommandLine.arguments.dropFirst()

do {
	for command in commands {
		switch command {
		case "download":
			try downloadFiles(params: commands.dropFirst())
		case "reshape":
			try reshapeGeometry(params: commands.dropFirst())
		case "tessellate":
			try tessellateGeometry(params: commands.dropFirst())
		case "bake":
			try bakeGeometry()
		default: print("Usage")
		}
	}
} catch GeoDownloadPipelineError.timedOut(let host) {
	print("Connection to \(host) timed out after 60 seconds")
} catch GeoDownloadPipelineError.downloadFailed(let key) {
	print("Could not download url referenced in \"\(key)\" in pipeline.json")
} catch GeoDownloadPipelineError.unpackFailed {
	print("Could not unzip the downloaded geometry file archive.")
} catch GeoReshapePipelineError.noNodePath {
	print("No node path set in pipeline.config. Please set absolute path to node in \"reshape.node\".")
} catch GeoReshapePipelineError.noMapshaperPath {
	print("No mapshaper path set in pipeline.config. Please set user-relative path to mapshaper in \"reshape.mapshaper\".")
} catch GeoReshapePipelineError.noMapshaperInstall {
	print("No mapshaper install available on PATH. Please run 'npm install -g mapshaper'")
} catch GeoReshapePipelineError.missingShapeFile(let level) {
	print("Could not find a \"\(level)\"-level shapefile. Please re-download.")
} catch GeoReshapePipelineError.noShapeFiles {
	print("Could not find any shapefiles. Please re-download.")
} catch GeoTessellatePipelineError.datasetFailed(let dataset) {
	print("Could not tessellate the \"\(dataset)\" dataset.")
} catch GeoTessellatePipelineError.tessellationFailed(let dataset) {
	print("Tessellation failed for the \"\(dataset)\" dataset.")
} catch GeoTessellatePipelineError.archivingFailed(let dataset) {
	print("Could not archive \"\(dataset)\" tessellation for following step.")
} catch GeoBakePipelineError.tessellationMissing {
	print("No tessellation archives found.")
}
catch {
	print("Could not bake geometry: \(error.localizedDescription)")
}
