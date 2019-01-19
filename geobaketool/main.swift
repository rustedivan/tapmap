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
default: print("Usage")
}

//case timedOut
//case downloadFailed
//case unpackFailed
