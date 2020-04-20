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
typealias GeoRegionMap = [RegionHash : GeoRegion]

class RuntimeWorld {
	let allContinents: GeoContinentMap
	let allCountries: GeoCountryMap
	let allRegions: GeoRegionMap
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
	
	// $ Recreating availability lists on every call is not great.
	var availableContinents: GeoContinentMap { get {
		let user = AppDelegate.sharedUserState
		return allContinents.filter { user.availableContinents.contains($0.key) }
	}}
	
	var availableCountries: GeoCountryMap { get {
		let user = AppDelegate.sharedUserState
		return allCountries.filter { user.availableCountries.contains($0.key) }
	}}
	
	var availableRegions: GeoRegionMap { get {
		let user = AppDelegate.sharedUserState
		return allRegions.filter { user.availableRegions.contains($0.key) }
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
	
	var visibleRegions: GeoRegionMap { get {
		let ui = AppDelegate.sharedUIState
		return availableRegions.filter { ui.visibleRegionHashes.contains($0.key) }
	}}
}
