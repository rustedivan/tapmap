//
//  OperationFixupHierarchy.swift
//  geobakeui
//
//  Created by Ivan Milles on 2018-10-22.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class OperationFixupHierarchy : Operation {
	var world : GeoWorld?
	let continentList : [GeoRegion]
	let countryList : [GeoRegion]
	let regionList : [GeoRegion]
	let report : ProgressReport
	
	init(continentCollection: [GeoRegion],
			 countryCollection: [GeoRegion],
			 regionCollection: [GeoRegion],
			 reporter: @escaping ProgressReport) {
		
		continentList = continentCollection
		countryList = countryCollection
		regionList = regionCollection
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		// Collect regions into their countries
		var remainingRegions = Set<GeoRegion>(regionList)
		var geoCountries = Set<GeoCountry>()
		let numRegions = remainingRegions.count
		for country in countryList {
			let belongingRegions = remainingRegions.filter {
				$0.admin == country.admin
			}
		
			let places = Set(belongingRegions.flatMap { $0.places })
			let newCountry = GeoCountry(geography: country,
																	regions: belongingRegions,
																	places: places)
			
			geoCountries.insert(newCountry)
			
			remainingRegions.subtract(belongingRegions)
			
			if (numRegions > 0) {
				report(1.0 - (Double(remainingRegions.count) / Double(numRegions)), country.name, false)
			}
		}
		report(1.0, "Collected \(regionList.count) regions into \(geoCountries.count) countries", true)
		
		// Collect countries into their continents
		var remainingCountries = geoCountries
		var geoContinents = Set<GeoContinent>()
		let numCountries = remainingCountries.count
		for continent in continentList {
			let belongingCountries = remainingCountries.filter {
				$0.continent == continent.name
			}
			
			let newContintent = GeoContinent(geography: continent,
																			 countries: belongingCountries,
																			 places: [])
			geoContinents.insert(newContintent)
			remainingCountries.subtract(belongingCountries)
			if (numCountries > 0) {
				report(1.0 - (Double(remainingCountries.count) / Double(numCountries)), continent.name, false)
			}
		}
		report(1.0, "Collected \(geoCountries.count) countries into \(geoContinents.count) continents", true)

		world = GeoWorld(continents: geoContinents)
		report(1.0, "Assembled completed world.", true)
		print("             - Continent regions:  \(continentList.count)")
		print("             - Country regions:  \(countryList.count)")
		print("             - Province regions: \(regionList.count)")
		
		if !remainingRegions.isEmpty {
			print("Remaining countries:")
			print(remainingCountries.map { "\($0.name) in \($0.admin)" })
		}

		if !remainingRegions.isEmpty {
			print("Remaining regions:")
			print(remainingRegions.map { "\($0.name) in \($0.admin)" })
		}
		
		print("\n")
	}
}
