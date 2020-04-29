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
	var availableContinents: Set<Int> = []
	var availableCountries: Set<Int> = []
	var availableProvinces: Set<Int> = []
	
	var availableSet: Set<Int> {
		return Set<Int>(availableContinents)
	var delegate: UserStateDelegate!
						 .union(availableCountries)
						 .union(availableProvinces)
	}
	
	func buildWorldAvailability(withWorld world: RuntimeWorld) {
		let allContinents = Set(world.allContinents.values)
		let closedContinents = allContinents.filter { placeVisited($0) == false }
		let openContinents = allContinents.subtracting(closedContinents)
		
		let allCountries = Set(openContinents.flatMap { $0.children })
		let closedCountries = allCountries.filter { placeVisited($0) == false }
		let openCountries = allCountries.subtracting(closedCountries)
		
		let allProvinces = Set(openCountries.flatMap { $0.children })
		let closedProvinces = allProvinces.filter { placeVisited($0) == false }
		
		availableContinents = Set(closedContinents.map { $0.geographyId.hashed })
		availableCountries = Set(closedCountries.map { $0.geographyId.hashed })
		availableProvinces = Set(closedProvinces.map { $0.geographyId.hashed })
		
		delegate.availabilityDidChange(availableSet: availableSet)
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
			availableContinents.remove(continent.geographyId.hashed)
			for newCountry in continent.children {
				availableCountries.insert(newCountry.geographyId.hashed)
			}
		case let country as GeoCountry:
			availableCountries.remove(country.geographyId.hashed)
			for newRegion in country.children {
				availableProvinces.insert(newRegion.geographyId.hashed)
			}
		default:
			break
		}
		
		delegate.availabilityDidChange(availableSet: availableSet)
	}
	
	func visitPlace(_ p: GeoProvince) {
		visitedPlaces[p.geographyId.hashed] = true
	}
}

protocol UserStateDelegate {
	func availabilityDidChange(availableSet: Set<RegionHash>)
}

