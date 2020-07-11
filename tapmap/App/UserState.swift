//
//  UserState.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-11-14.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation
import CloudKit

class UserState {
	static let visitedPlacesKey = "visited-places"
	var visitedPlaces: [RegionHash : Bool] = [:]
	var availableContinents: Set<RegionHash> = []
	var availableCountries: Set<RegionHash> = []
	var availableProvinces: Set<RegionHash> = []
	
	var delegate: UserStateDelegate!
	var persistentProfileUrl: URL {
		try! FileManager.default
			.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			.appendingPathComponent("\(UserState.visitedPlacesKey).plist")
	}
	
	var availableSet: Set<RegionHash> {
		return Set<RegionHash>(availableContinents)
						 .union(availableCountries)
						 .union(availableProvinces)
	}
	
	init() {
		if let profile = NSData(contentsOf: persistentProfileUrl) as Data? {
			let persistedState = NSKeyedUnarchiver(forReadingWith: profile)
			visitedPlaces = persistedState.decodeObject(forKey: UserState.visitedPlacesKey) as! [RegionHash : Bool]
		}
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
		persistToProfile()
		persistToCloud()
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
			return
		}
		
		delegate.availabilityDidChange(availableSet: availableSet)
		persistToProfile()
		persistToCloud()
	}
	
	func persistToProfile() {
		var url = persistentProfileUrl
		// Expect tapmap to run offline for long periods, so don't allow iOS to offload the savefile to iCloud
		var dontOffloadUserstate = URLResourceValues()
		dontOffloadUserstate.isExcludedFromBackup = true
		try? url.setResourceValues(dontOffloadUserstate)
		
		let encoder = NSKeyedArchiver()
		encoder.encode(10, forKey: "version")
		encoder.encode(Date(), forKey: "archive-timestamp")
		encoder.encode(visitedPlaces, forKey: UserState.visitedPlacesKey)
		let chunk = encoder.encodedData
		
		do {
			try chunk.write(to: url, options: .atomic)
		} catch (let error) {
			print("Could not persist to profile at \(url): \(error.localizedDescription)")
		}
	}
	
	func persistToCloud() {
		let storedPlaces = visitedPlaces.compactMap { (key, value) in (value ? String(key) : nil) }
		NSUbiquitousKeyValueStore.default.set(storedPlaces, forKey: UserState.visitedPlacesKey)
	}
}

protocol UserStateDelegate {
	func availabilityDidChange(availableSet: Set<RegionHash>)
}

