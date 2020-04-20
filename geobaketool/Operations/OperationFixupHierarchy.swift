//
//  OperationFixupHierarchy.swift
//  geobakeui
//
//  Created by Ivan Milles on 2018-10-22.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class OperationFixupHierarchy : Operation {
	let continentList : ToolGeoFeatureMap
	let countryList : ToolGeoFeatureMap
	let provinceList : ToolGeoFeatureMap
	
	var output : ToolGeoFeatureMap?
	let report : ProgressReport
	
	init(continentCollection: ToolGeoFeatureMap,
			 countryCollection: ToolGeoFeatureMap,
			 provinceCollection: ToolGeoFeatureMap,
			 reporter: @escaping ProgressReport) {
		
		continentList = continentCollection
		countryList = countryCollection
		provinceList = provinceCollection
		report = reporter
		
		output = [:]
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		// Collect provinces into their countries
		var remainingProvinces = Set(provinceList.values)
		var geoCountries = ToolGeoFeatureMap()
		let numProvinces = remainingProvinces.count
		for (key, country) in countryList {
			// Countries consist of their provinces...
			let belongingProvinces = remainingProvinces.filter { $0.countryKey == country.countryKey }
			// ...and all the larger places in those provinces
			let belongingPlaces = Set(belongingProvinces
				.flatMap { $0.places ?? [] }
				.filter { $0.kind != .Town }	// Don't promote towns and region labels
				.filter { $0.kind != .Region }
			)
			
			var updatedCountry = country
			updatedCountry.children = belongingProvinces
			updatedCountry.places = (country.places ?? Set()).union(belongingPlaces)
			
			geoCountries[key] = updatedCountry
			
			remainingProvinces.subtract(belongingProvinces)
			
			if (numProvinces > 0) {
				report(1.0 - (Double(remainingProvinces.count) / Double(numProvinces)), country.name, false)
			}
		}
		report(1.0, "Collected \(numProvinces - remainingProvinces.count) provinces into \(geoCountries.count) countries", true)
		
		// Collect countries into their continents
		var remainingCountries = Set(geoCountries.values)
		var geoContinents = ToolGeoFeatureMap()
		let numCountries = remainingCountries.count
		for (key, continent) in continentList {
			let belongingCountries = remainingCountries.filter { $0.continentKey == continent.continentKey }
			let belongingPlaces = Set(belongingCountries
				.flatMap { $0.places ?? [] }
				.filter { $0.kind == .Capital }
			)
			
			var updatedContinent = continent
			updatedContinent.children = belongingCountries
			updatedContinent.places = (continent.places ?? Set()).union(belongingPlaces)
			geoContinents[key] = updatedContinent
			
			remainingCountries.subtract(belongingCountries)
			if (numCountries > 0) {
				report(1.0 - (Double(remainingCountries.count) / Double(numCountries)), continent.name, false)
			}
		}
		report(1.0, "Collected \(geoCountries.count) countries into \(geoContinents.count) continents", true)

		output = geoContinents
		
		report(1.0, "Assembled completed world.", true)
		print("             - Continent regions:  \(continentList.count)")
		print("             - Country regions:  \(countryList.count)")
		print("             - Province regions: \(provinceList.count)")
		
		if !remainingCountries.isEmpty {
			print("Remaining countries:")
			print(remainingCountries.map { "\($0.name) - \($0.continentKey)" })
		}

		if !remainingProvinces.isEmpty {
			print("Remaining provinces:")
			print(remainingProvinces.map { "\($0.name) - \($0.countryKey)" })
		}
		
		print("\n")
	}
}
