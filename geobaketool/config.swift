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
				print("Top-level object of pipeline.json must be a dictionary.")
			}
		} catch {
			print("Could not load pipeline configuration: \(error.localizedDescription)")
		}
		dictionary = [:]
	}
	
	func sourceUrl(_ filename: String, forKey key: String) -> URL {
		if let url = URL(string: filename) {
			return url
		} else {
			print("Value for \"\(key)\" is not a valid URL.")
			exit(1)
		}
	}
	
	func configString(_ key : String) -> String {
		if let string = dictionary.value(forKeyPath: key) as? String {
			return string
		} else {
			print("Could not find pipeline configuration value for \"\(key)\".")
			exit(1)
		}
	}
	
	func keyToSourceFileURL(_ key: String) -> URL { return sourceUrl(configString(key), forKey: key) }
	
	var sourceCountryUrl : URL { return keyToSourceFileURL("source.countries") }
	var sourceRegionUrl : URL { return keyToSourceFileURL("source.regions") }
}
