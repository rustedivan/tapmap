//
//  config.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-17.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class PipelineConfig {
	static let shared = PipelineConfig()
	let dictionary : NSDictionary
	
	private init() {
		let configFile = URL(fileURLWithPath: "pipeline.json")
		do {
			let data = try Data(contentsOf: configFile)
			let json = try JSONSerialization.jsonObject(with: data)
			if let dict = json as? NSDictionary {
				dictionary = dict
				return
			} else {
				print("Pipeline configuration error: Top-level object of pipeline.json must be a dictionary.")
			}
		} catch {
			print("Could not load pipeline configuration: \(error.localizedDescription)")
		}
		dictionary = [:]
	}
	
	fileprivate func sourceUrl(_ filename: String, forKey key: String) -> URL {
		if let url = URL(string: filename) {
			return url
		} else {
			print("Pipeline configuration error: value for \"\(key)\" is not a valid URL.")
			exit(1)
		}
	}
	
	fileprivate func configString(_ key : String) -> String {
		if let string = dictionary.value(forKeyPath: key) as? String {
			return string
		} else {
			print("Pipeline configuration error: Could not find value for \"\(key)\".")
			exit(1)
		}
	}
	
	fileprivate func configValue(_ key : String, fallback: Int = 0) -> Int {
		guard let val = dictionary.value(forKeyPath: key) else {
			return fallback
		}
		guard let confInt = val as? Int else {
			print("Pipeline configuration error: \"\(key)\" must be an integer.")
			exit(1)
		}
		return confInt
	}
	
	fileprivate func keyToSourceFileURL(_ key: String) -> URL { return sourceUrl(configString(key), forKey: key) }
	
	var sourceCountryUrl : URL { return keyToSourceFileURL("source.countries") }
	var sourceRegionUrl : URL { return keyToSourceFileURL("source.regions") }
	var nodePath : String? { return dictionary.value(forKeyPath: "reshape.node") as? String }
	var reshapeMethod : String { return configString("reshape.method") }
	var countrySimplification : Int { return configValue("reshape.simplify-countries") }
	var regionSimplification : Int { return configValue("reshape.simplify-regions") }
	var reshapedCountriesFilePath : URL {
		return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
			.appendingPathComponent(PipelineConfig.sourceDirectory)
			.appendingPathComponent(PipelineConfig.reshapedCountriesFilename)
	}
	var reshapedRegionsFilePath : URL {
		return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
			.appendingPathComponent(PipelineConfig.sourceDirectory)
			.appendingPathComponent(PipelineConfig.reshapedRegionsFilename)
	}
	var outputFilePath : URL {
		let setting = configString("output")
		return URL(fileURLWithPath: setting, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
	}
	
	// Constants
	static let sourceDirectory = "source-geometry"
	static let reshapedCountriesFilename = "reshaped-countries.json"
	static let reshapedRegionsFilename = "reshaped-regions.json"
}

typealias ProgressBar = (Int, String) -> ()

func makeBar(bar fill: Character, of width: Int, on back: Character) -> ProgressBar {
	return { (length: Int, message: String) in
		let bar = Array(repeating: back, count: width).enumerated()
			.map { ($0.offset < length ? fill : back) }
		
		print("\u{1B}[2K\r" + String(bar) + " \(message)", terminator: "")
		fflush(__stdoutp)
	}
}

let progressBar = makeBar(bar: "\u{25cd}", of: 10, on: "\u{25cb}")
