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
			let countryAabb = country.aabb
			let candidateRegions = remainingRegions.filter {
				let regionCenter = CGPoint(x: $0.aabb.midpoint.x, y: $0.aabb.midpoint.y)
				return aabbHitTest(p: regionCenter, aabb: countryAabb)
			}
			let belongingRegions = candidateRegions.filter {
				let regionCenter = CGPoint(x: $0.aabb.midpoint.x, y: $0.aabb.midpoint.y)
				return pickFromTessellations(p: regionCenter, candidates: Set([country])) != nil
			}
			
			print(country.name)
			print(belongingRegions.map { $0.name }.joined(separator: ", "))
			
			let places = Set(belongingRegions.flatMap { $0.places })
			
			let newCountry = GeoCountry(name: country.name,
																	children: belongingRegions,
																	places: places,
																	geometry: country.geometry)
			
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
			let continentAabb = continent.aabb
			let belongingCountries = remainingCountries.filter {
				let countryCenter = CGPoint(x: $0.aabb.midpoint.x, y: $0.aabb.midpoint.y)
				return aabbHitTest(p: countryCenter, aabb: continentAabb) &&
							 pickFromTessellations(p: countryCenter, candidates: Set([continent])) != nil
			}
			
			let newContintent = GeoContinent(name: continent.name,
																			 children: belongingCountries,
																			 geometry: continent.geometry)
			
			geoContinents.insert(newContintent)
			remainingCountries.subtract(belongingCountries)
			if (numCountries > 0) {
				report(1.0 - (Double(remainingCountries.count) / Double(numCountries)), continent.name, false)
			}
		}
		report(1.0, "Collected \(geoCountries.count) countries into \(geoContinents.count) continents", true)

		world = GeoWorld(name: "Earth",
										 children: geoContinents)
		
		report(1.0, "Assembled completed world.", true)
		print("             - Continent regions:  \(continentList.count)")
		print("             - Country regions:  \(countryList.count)")
		print("             - Province regions: \(regionList.count)")
		
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
