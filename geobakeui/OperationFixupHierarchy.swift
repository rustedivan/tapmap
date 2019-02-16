//
//  OperationFixupHierarchy.swift
//  geobakeui
//
//  Created by Ivan Milles on 2018-10-22.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class OperationFixupHierarchy : Operation {
	let continentList : Set<ToolGeoFeature>
	let countryList : Set<ToolGeoFeature>
	let regionList : Set<ToolGeoFeature>
	
	var output : Set<ToolGeoFeature>?
	let report : ProgressReport
	
	init(continentCollection: Set<ToolGeoFeature>,
			 countryCollection: Set<ToolGeoFeature>,
			 regionCollection: Set<ToolGeoFeature>,
			 reporter: @escaping ProgressReport) {
		
		continentList = continentCollection
		countryList = countryCollection
		regionList = regionCollection
		report = reporter
		
		output = []
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		// Collect regions into their countries
		var remainingRegions = regionList
		var geoCountries = Set<ToolGeoFeature>()
		let numRegions = remainingRegions.count
		for country in countryList {
			let belongingRegions = remainingRegions.filter {	$0.countryKey == country.countryKey	}
			let belongingPlaces = Set(belongingRegions.flatMap { $0.places ?? [] })
			
			var updatedCountry = country
			updatedCountry.children = belongingRegions
			updatedCountry.places = belongingPlaces
			
			geoCountries.insert(updatedCountry)
			
			remainingRegions.subtract(belongingRegions)
			
			if (numRegions > 0) {
				report(1.0 - (Double(remainingRegions.count) / Double(numRegions)), country.name, false)
			}
		}
		report(1.0, "Collected \(numRegions - remainingRegions.count) regions into \(geoCountries.count) countries", true)
		
		// Collect countries into their continents
		var remainingCountries = geoCountries
		var geoContinents = Set<ToolGeoFeature>()
		let numCountries = remainingCountries.count
		for continent in continentList {
			let belongingCountries = remainingCountries.filter { $0.continentKey == continent.name }
			
			var updatedContinent = continent
			updatedContinent.children = belongingCountries
			geoContinents.insert(updatedContinent)
			
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
		print("             - Province regions: \(regionList.count)")
		
		if !remainingRegions.isEmpty {
			print("Remaining countries:")
			print(remainingCountries.map { "\($0.name) - \($0.continentKey)" })
		}

		if !remainingRegions.isEmpty {
			print("Remaining regions:")
			print(remainingRegions.map { "\($0.name) - \($0.countryKey)" })
		}
		
		print("\n")
	}
}
