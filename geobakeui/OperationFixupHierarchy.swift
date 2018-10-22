//
//  OperationFixupHierarchy.swift
//  geobakeui
//
//  Created by Ivan Milles on 2018-10-22.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class OperationFixupHierarchy : Operation {
	let countries : GeoFeatureCollection
	let regions : GeoFeatureCollection
	let report : ProgressReport
	
	init(countryCollection: GeoFeatureCollection,
			 regionCollection: GeoFeatureCollection,
			 reporter: @escaping ProgressReport) {
		
		countries = countryCollection
		regions = regionCollection
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var remainingRegions = regions.features
		
		for country in countries.features {
			let belongingRegions = remainingRegions.filter {
				$0.admin == country.admin
			}
			
			print(country.name.uppercased())
			for subRegion in belongingRegions {
				print("\t\(subRegion.name)")
			}
		}
	}
}
