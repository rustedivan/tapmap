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
	let allContinents: GeoContinentMap
	let allCountries: GeoCountryMap
	let allProvinces: GeoProvinceMap
	let geoWorld: GeoWorld
	
	init(withGeoWorld world: GeoWorld) {
		geoWorld = world
		
		let continentList = geoWorld.children
		allContinents = Dictionary(uniqueKeysWithValues: continentList.map { ($0.geographyId.hashed, $0)})
		
		let countryList = continentList.flatMap { $0.children }
		allCountries = Dictionary(uniqueKeysWithValues: countryList.map { ($0.geographyId.hashed, $0) })
		
		let provinceList = countryList.flatMap { $0.children }
		allProvinces = Dictionary(uniqueKeysWithValues: provinceList.map { ($0.geographyId.hashed, $0) })
	}
	
	// $ Recreating availability lists on every call is not great.
	var availableContinents: GeoContinentMap { get {
		let user = AppDelegate.sharedUserState
		return allContinents.filter { user.availableContinents.contains($0.key) }
	}}
	
	var availableCountries: GeoCountryMap { get {
		let user = AppDelegate.sharedUserState
		return allCountries.filter { user.availableCountries.contains($0.key) }
	}}
	
	var availableProvinces: GeoProvinceMap { get {
		let user = AppDelegate.sharedUserState
		return allProvinces.filter { user.availableProvinces.contains($0.key) }
	}}
	
	// $ Likewise, these visibility filters could be recreated at the end of frame or zoom
	var visibleContinents: GeoContinentMap { get {
		let ui = AppDelegate.sharedUIState
		return availableContinents.filter { ui.visibleRegionHashes.contains($0.key) }
	}}
	
	var visibleCountries: GeoCountryMap { get {
		let ui = AppDelegate.sharedUIState
		return availableCountries.filter { ui.visibleRegionHashes.contains($0.key) }
	}}
	
	var visibleProvinces: GeoProvinceMap { get {
		let ui = AppDelegate.sharedUIState
		return availableProvinces.filter { ui.visibleRegionHashes.contains($0.key) }
	}}
}
