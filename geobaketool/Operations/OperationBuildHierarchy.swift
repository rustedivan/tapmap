//
//  OperationFixupHierarchy.swift
//  geobakeui
//
//  Created by Ivan Milles on 2020-02-02.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class OperationBuildHierarchy : Operation {
	let countryList : Set<ToolGeoFeature>
	let regionList : Set<ToolGeoFeature>
	
	var outputRegionCountryMapping: Dictionary<String, String> = [:]
	var outputCountryRegionList: Dictionary<String, [String]> = [:]
	var outputCountryContinentMapping: Dictionary<String, String> = [:]
	var outputContinentCountryList: Dictionary<String, [String]> = [:]
	let report : ProgressReport
	
	init(countries countryCollection: Set<ToolGeoFeature>,
			 regions regionCollection: Set<ToolGeoFeature>,
			 reporter: @escaping ProgressReport) {
		
		countryList = countryCollection
		regionList = regionCollection
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		// Collect regions into their countries
		for region in regionList {
			outputRegionCountryMapping[region.name] = region.countryKey
			outputCountryRegionList[region.countryKey, default: []].append(region.name)
		}
		report(1.0, "Collected \(regionList.count) regions into \(outputRegionCountryMapping.count) countries", true)
		
		// Collect countries into their continents
		for country in countryList {
			outputCountryContinentMapping[country.countryKey] = country.continentKey
			outputContinentCountryList[country.continentKey, default: []].append(country.countryKey)
		}
		report(1.0, "Collected \(countryList.count) countries into \(outputCountryContinentMapping.count) continents", true)
		
		report(1.0, "Created hierarchy.", true)
		for continentCountries in outputContinentCountryList {
			print("  - \(continentCountries.key):  \(continentCountries.value.count)")
		}
		print("\n")
	}
}
