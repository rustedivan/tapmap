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
	
	var availableSet: Set<Int> {
		return Set<Int>(availableContinents.keys)
						 .union(availableCountries.keys)
						 .union(availableRegions.keys)
	}
	
	func buildWorldAvailability(withWorld geoWorld: GeoWorld) {
		let allContinents = geoWorld.children
		let closedContinents = allContinents.filter { placeVisited($0) == false }
		let openContinents = allContinents.subtracting(closedContinents)
		
		let allCountries = Set(openContinents.flatMap { $0.children })
		let closedCountries = allCountries.filter { placeVisited($0) == false }
		let openCountries = allCountries.subtracting(closedCountries)
		
		let allRegions = Set(openCountries.flatMap { $0.children })
		let closedRegions = allRegions.filter { placeVisited($0) == false }
		
		availableContinents = Dictionary(uniqueKeysWithValues: closedContinents.map { ($0.geographyId.hashed, $0) })
		availableCountries = Dictionary(uniqueKeysWithValues: closedCountries.map { ($0.geographyId.hashed, $0) })
		availableRegions = Dictionary(uniqueKeysWithValues: closedRegions.map { ($0.geographyId.hashed, $0) })
	}
	
	func placeVisited<T:GeoIdentifiable>(_ p: T) -> Bool {
		return visitedPlaces[p.geographyId.hashed] ?? false
	}
	
	func visitPlace<T:GeoIdentifiable>(_ p: T) {
		visitedPlaces[p.geographyId.hashed] = true
	}
	
	func openPlace<T:GeoNode>(_ p: T) {
		switch (p) {
		case let continent as GeoContinent:
			availableContinents.removeValue(forKey: continent.geographyId.hashed)
			for newCountry in continent.children {
				availableCountries[newCountry.geographyId.hashed] = newCountry
			}
		case let country as GeoCountry:
			availableCountries.removeValue(forKey: country.geographyId.hashed)
			for newRegion in country.children {
				availableRegions[newRegion.geographyId.hashed] = newRegion
			}
		default:
			break
		}
	}
	
	func visitPlace(_ p: GeoRegion) {
		visitedPlaces[p.geographyId.hashed] = true
	}
}
