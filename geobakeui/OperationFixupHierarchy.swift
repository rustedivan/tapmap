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
	let countryList : [GeoRegion]
	let regionList : [GeoRegion]
	let report : ProgressReport
	
	init(countryCollection: [GeoRegion],
			 regionCollection: [GeoRegion],
			 reporter: @escaping ProgressReport) {
		
		countryList = countryCollection
		regionList = regionCollection
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var remainingRegions = Set<GeoRegion>(regionList)
		
		var geoCountries = Set<GeoCountry>()
		
		let numRegions = remainingRegions.count
		for country in countryList {
			let belongingRegions = remainingRegions.filter {
				$0.admin == country.admin
			}
			
			let newCountry = GeoCountry(geography: country,
																	regions: belongingRegions)
			
			geoCountries.insert(newCountry)
			
			remainingRegions.subtract(belongingRegions)
			report(1.0 - (Double(remainingRegions.count) / Double(numRegions)), country.name, false)
		}
		
		world = GeoWorld(countries: geoCountries)
		report(1.0, "Assembled completed world.", true)
		print("             - Country regions:  \(countryList.count)")
		print("             - Province regions: \(regionList.count)")
		print("\n")
		
		if !remainingRegions.isEmpty {
			print("Remaining regions:")
			print(remainingRegions.map { "\($0.name) in \($0.admin)" })
		}
	}
}
