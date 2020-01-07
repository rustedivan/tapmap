//
//  UserState.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-11-14.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class UserState {
	var visitedPlaces: [Int : Bool] = [:]
	var availableContinents: [Int : GeoContinent] = [:]
	var availableCountries: [Int : GeoCountry] = [:]
	var availableRegions: [Int : GeoRegion] = [:]

	func buildWorldAvailability(withWorld geoWorld: GeoWorld) {
		let allContinents = geoWorld.children
		let closedContinents = allContinents.filter { placeVisited($0) == false }
		let openContinents = allContinents.subtracting(closedContinents)
		
		let allCountries = Set(openContinents.flatMap { $0.children })
		let closedCountries = allCountries.filter { placeVisited($0) == false }
		let openCountries = allCountries.subtracting(closedCountries)
		
		let allRegions = Set(openCountries.flatMap { $0.children })
		let closedRegions = allRegions.filter { placeVisited($0) == false }
		
		availableContinents = Dictionary(uniqueKeysWithValues: closedContinents.map { ($0.hashValue, $0) })
		availableCountries = Dictionary(uniqueKeysWithValues: closedCountries.map { ($0.hashValue, $0) })
		availableRegions = Dictionary(uniqueKeysWithValues: closedRegions.map { ($0.hashValue, $0) })
	}
	
	func placeVisited<T:Hashable>(_ p: T) -> Bool {
		return visitedPlaces[p.hashValue] ?? false
	}
	
	func visitPlace<T:Hashable>(_ p: T) {
		visitedPlaces[p.hashValue] = true
		
		switch (p) {
		case let continent as GeoContinent:
			availableContinents.removeValue(forKey: continent.hashValue)
			for newCountry in continent.children {
				availableCountries[newCountry.hashValue] = newCountry
			}
		case let country as GeoCountry:
			availableCountries.removeValue(forKey: country.hashValue)
			for newRegion in country.children {
				availableRegions[newRegion.hashValue] = newRegion
			}
		default:
			break
		}
	}
}
