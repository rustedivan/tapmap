//
//  RuntimeWorld.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-04-18.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

typealias GeoContinentMap = [RegionHash : GeoContinent]
typealias GeoCountryMap = [RegionHash : GeoCountry]
typealias GeoProvinceMap = [RegionHash : GeoProvince]

class RuntimeWorld {
	// Complete set
	let allContinents: GeoContinentMap
	let allCountries: GeoCountryMap
	let allProvinces: GeoProvinceMap
	
	// Closed set
	var availableContinents: GeoContinentMap = [:]
	var availableCountries: GeoCountryMap = [:]
	var availableProvinces: GeoProvinceMap = [:]
	
	// Visible set
	var visibleContinents: GeoContinentMap = [:]
	var visibleCountries: GeoCountryMap = [:]
	var visibleProvinces: GeoProvinceMap = [:]
	
	// Lookups and mappings
	let continentForRegion: GeoContinentMap
	
	let geoWorld: GeoWorld
	
	init(withGeoWorld world: GeoWorld) {
		geoWorld = world
		
		let continentList = geoWorld.children
		allContinents = Dictionary(uniqueKeysWithValues: continentList.map { ($0.geographyId.hashed, $0)})
		
		let countryList = continentList.flatMap { $0.children }
		allCountries = Dictionary(uniqueKeysWithValues: countryList.map { ($0.geographyId.hashed, $0) })
		
		let provinceList = countryList.flatMap { $0.children }
		allProvinces = Dictionary(uniqueKeysWithValues: provinceList.map { ($0.geographyId.hashed, $0) })
		
		// Note which continent a region belongs to (including the continents themselves)
		var regionHashToContinentMap: GeoContinentMap = [:]
		for continent in continentList {
			let countries = continent.children
			let countryHashes = countries.map { $0.geographyId.hashed }
			let provinces = countries.flatMap { $0.children }
			let provinceHashes = provinces.map { $0.geographyId.hashed }
			let allContinentHashes = [continent.geographyId.hashed] + countryHashes + provinceHashes
			for h in allContinentHashes {
				regionHashToContinentMap[h] = continent
			}
		}
		continentForRegion = regionHashToContinentMap
	}
}

extension RuntimeWorld: UIStateDelegate, UserStateDelegate {
	func availabilityDidChange(availableSet: Set<RegionHash>) {
		availableContinents = allContinents.filter { availableSet.contains($0.key) }
		availableCountries = allCountries.filter { availableSet.contains($0.key) }
		availableProvinces = allProvinces.filter { availableSet.contains($0.key) }
	}
	
	func visibilityDidChange(visibleSet: Set<RegionHash>) {
		visibleContinents = availableContinents.filter { visibleSet.contains($0.key) }
		visibleCountries = availableCountries.filter { visibleSet.contains($0.key) }
		visibleProvinces = availableProvinces.filter { visibleSet.contains($0.key) }
	}
}
	
