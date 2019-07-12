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
	
	func configUrl(_ key: String) -> URL? {
		guard let filename = configString(key) else { return nil }
		if let url = URL(string: filename) {
			return url
		} else {
			print("Pipeline configuration warning: value for \"\(key)\" is not a valid URL.")
			return nil
		}
	}
	
	func configString(_ key : String) -> String? {
		if let string = dictionary.value(forKeyPath: key) as? String {
			return string
		} else {
			print("Pipeline configuration warning: Could not find value for \"\(key)\".")
			return nil
		}
	}
	
	func configValue(_ key : String, fallback: Int = 0) -> Int {
		guard let val = dictionary.value(forKeyPath: key) else {
			return fallback
		}
		guard let confInt = val as? Int else {
			print("Pipeline configuration error: \"\(key)\" must be an integer.")
			exit(1)
		}
		return confInt
	}
	
	func configArray(_ key : String) -> [String]? {
		var out : [String]? = nil
		if let arr = dictionary.value(forKeyPath: key) as? NSArray {
			out = arr as? [String]
		}
		return out
	}
	
	fileprivate let appIdentifier = "se.rusted.tapmap"
	fileprivate var applicationSupportUrl : URL {
		return try! FileManager.default.url(for: .applicationSupportDirectory,
																				in: .userDomainMask,
																				appropriateFor: nil,
																				create: true)
		.appendingPathComponent(appIdentifier);
	}
	
	var sourceGeometryUrl: URL {
		return PipelineConfig.shared.applicationSupportUrl
	}
	
	var reshapedCountriesFilePath : URL {
		return applicationSupportUrl.appendingPathComponent(PipelineConfig.shared.reshapedCountriesFilename)
	}
	var reshapedRegionsFilePath : URL? {
		guard let file = PipelineConfig.shared.reshapedRegionsFilename else { return nil }
		return applicationSupportUrl.appendingPathComponent(file)
	}
	var queriedCitiesFilePath : URL? {
		guard let file = PipelineConfig.shared.reshapedCitiesFilename else { return nil }
		return applicationSupportUrl.appendingPathComponent(file)
	}
	
	var outputFilePath : URL? {
		guard let setting = configString("output") else { return nil }
		return URL(fileURLWithPath: setting, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
	}
	
	// Constants
	var reshapedCountriesFilename: String { return configString("input-countries")! }
	var reshapedRegionsFilename: String? { return configString("input-regions") }
	var reshapedCitiesFilename: String? { return configString("input-cities") }
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

func reportLoad(_ progress: Double, _ message: String, _ done: Bool) {
	progressBar(Int(progress * 10.0), done ? "√ \(message)\n" : "  \(message)")
}
