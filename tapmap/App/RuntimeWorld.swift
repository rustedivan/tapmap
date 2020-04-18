//
//  RuntimeWorld.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-04-18.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class RuntimeWorld {
	let allContinents: [Int : GeoContinent]
	let allCountries: [Int : GeoCountry]
	let allRegions: [Int : GeoRegion]
	let geoWorld: GeoWorld
	
	init(withGeoWorld world: GeoWorld) {
		geoWorld = world
		
		let continentList = geoWorld.children
		allContinents = Dictionary(uniqueKeysWithValues: continentList.map { ($0.geographyId.hashed, $0)})
		
		let countryList = continentList.flatMap { $0.children }
		allCountries = Dictionary(uniqueKeysWithValues: countryList.map { ($0.geographyId.hashed, $0) })
		
		let regionList = countryList.flatMap { $0.children }
		allRegions = Dictionary(uniqueKeysWithValues: regionList.map { ($0.geographyId.hashed, $0) })
	}
}
