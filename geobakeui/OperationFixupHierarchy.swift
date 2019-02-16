//
//  OperationFixupHierarchy.swift
//  geobakeui
//
//  Created by Ivan Milles on 2018-10-22.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class OperationFixupHierarchy : Operation {
	let continentList : ToolGeoFeatureCollection
	let countryList : ToolGeoFeatureCollection
	let regionList : ToolGeoFeatureCollection
	
	var output : ToolGeoFeatureCollection
	let report : ProgressReport
	
	init(continentCollection: ToolGeoFeatureCollection,
			 countryCollection: ToolGeoFeatureCollection,
			 regionCollection: ToolGeoFeatureCollection,
			 reporter: @escaping ProgressReport) {
		
		continentList = continentCollection
		countryList = countryCollection
		regionList = regionCollection
		report = reporter
		
		output = ToolGeoFeatureCollection(features: [])
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		// Collect regions into their countries
		var remainingRegions = regionList.features
		var geoCountries = Set<ToolGeoFeature>()
		let numRegions = remainingRegions.count
		for country in countryList.features {
			let belongingRegions = remainingRegions.filter {	$0.admin == country.admin	}
			let places = Set(belongingRegions.flatMap { $0.places ?? [] })
			
			let newCountry = ToolGeoFeature(level: .Country,
																			polygons: country.polygons,
																			tessellation: country.tessellation,
																			places: places,
																			children: ToolGeoFeatureCollection(features: belongingRegions),
																			stringProperties: country.stringProperties,
																			valueProperties: country.valueProperties)
			
			geoCountries.insert(newCountry)
			
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
		for continent in continentList.features {
			let belongingCountries = remainingCountries.filter { $0.continent == continent.name }
			
			let newContinent = ToolGeoFeature(level: .Continent,
																				polygons: continent.polygons,
																				tessellation: continent.tessellation,
																				places: nil,
																				children: ToolGeoFeatureCollection(features: belongingCountries),
																				stringProperties: continent.stringProperties,
																				valueProperties: continent.valueProperties)
			
			geoContinents.insert(newContinent)
			remainingCountries.subtract(belongingCountries)
			if (numCountries > 0) {
				report(1.0 - (Double(remainingCountries.count) / Double(numCountries)), continent.name, false)
			}
		}
		report(1.0, "Collected \(geoCountries.count) countries into \(geoContinents.count) continents", true)

		output = ToolGeoFeatureCollection(features: geoContinents)
		
		report(1.0, "Assembled completed world.", true)
		print("             - Continent regions:  \(continentList.features.count)")
		print("             - Country regions:  \(countryList.features.count)")
		print("             - Province regions: \(regionList.features.count)")
		
		if !remainingRegions.isEmpty {
			print("Remaining countries:")
			print(remainingCountries.map { "\($0.name)" })
		}

		if !remainingRegions.isEmpty {
			print("Remaining regions:")
			print(remainingRegions.map { "\($0.name)" })
		}
		
		print("\n")
	}
}
