//
//  CloudProfile.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-07-11.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

struct UserStateDiff {
	let continentVisits: [GeoContinent]
	let countryVisits: [GeoCountry]
	let provinceVisits: [GeoProvince]
}

func mergeCloudProfile(notification: Notification, world: RuntimeWorld) -> UserStateDiff? {
	guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? NSArray else {
		print("Notification did not carry any changed keys.")
		return nil
	}
	guard changedKeys.contains(UserState.visitedPlacesKey) else {
		print("Notification did not carry visited places.")
		return nil
	}
	
	guard let cloudVisits = downloadVisitsFromCloudKVS(key: UserState.visitedPlacesKey) else {
		print("Stored profile wasn't an array.")
		return nil
	}

	let userState = AppDelegate.sharedUserState
	let newVisits = cloudVisits.filter { !(userState.visitedPlaces[$0] ?? false) }
	let newContinentVisits = world.allContinents.filter { newVisits.contains($0.key) }.values
	let newCountryVisits = world.allCountries.filter { newVisits.contains($0.key) }.values
	let newProvinceVisits = world.allProvinces.filter { newVisits.contains($0.key) }.values
	
	if newVisits.isEmpty == false {
		print("New visits synched from iCloud: \(newVisits.count)")
		print(" Continents: \(newContinentVisits.map { $0.name })")
		print("  Countries: \(newCountryVisits.map { $0.name })")
		print("  Provinces: \(newProvinceVisits.map { $0.name })")
	} else {
		print("iCloud synch had no unseen visits")
		return nil
	}
	
	for newContinent in newContinentVisits {
		userState.visitPlace(newContinent)
	}
	for newCountry in newCountryVisits {
		userState.visitPlace(newCountry)
	}
	for newProvince in newProvinceVisits {
		userState.visitPlace(newProvince)
	}
	
	// Save and publish merged data
	userState.persistToProfile()
	userState.persistToCloud()
	
	return UserStateDiff(continentVisits: Array(newContinentVisits),
											 countryVisits: Array(newCountryVisits),
											 provinceVisits: Array(newProvinceVisits))
}

func uploadVisitsToCloudKVS(_ hashes: [RegionHash : Bool], as key: String) {
	let stringKeys = hashes.compactMap { (key, value) in (value ? String(key) : nil) }
	NSUbiquitousKeyValueStore.default.set(stringKeys, forKey: key)
}

func downloadVisitsFromCloudKVS(key: String) -> [RegionHash]? {
	guard let storedPlaces = NSUbiquitousKeyValueStore.default.array(forKey: key) else {
		return nil
	}

	let cloudVisits = storedPlaces.compactMap { (k) -> RegionHash? in
		if let keyString = k as? String {
			return RegionHash(keyString)
		} else {
			return nil
		}
	}
	
	return cloudVisits
}
