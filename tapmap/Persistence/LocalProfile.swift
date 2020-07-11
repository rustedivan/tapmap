//
//  LocalProfile.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-07-11.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

var persistentProfileUrl: URL {
	try! FileManager.default
		.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		.appendingPathComponent("\(UserState.visitedPlacesKey).plist")
}

func saveVisitsToDevice(_ hashes: [RegionHash : Bool], as key: String) {
	var url = persistentProfileUrl
	// Expect tapmap to run offline for long periods, so don't allow iOS to offload the savefile to iCloud
	var dontOffloadUserstate = URLResourceValues()
	dontOffloadUserstate.isExcludedFromBackup = true
	try? url.setResourceValues(dontOffloadUserstate)
	
	let encoder = NSKeyedArchiver()
	encoder.encode(10, forKey: "version")
	encoder.encode(Date(), forKey: "archive-timestamp")
	encoder.encode(hashes, forKey: key)
	let chunk = encoder.encodedData
	
	do {
		try chunk.write(to: url, options: .atomic)
	} catch (let error) {
		print("Could not persist to profile at \(url): \(error.localizedDescription)")
	}
}

func loadVisitsFromDevice(key: String) -> [RegionHash : Bool]? {
	if let profile = NSData(contentsOf: persistentProfileUrl) as Data? {
		let persistedState = NSKeyedUnarchiver(forReadingWith: profile)
		return persistedState.decodeObject(forKey: key) as? [RegionHash : Bool]
	} else {
		return nil
	}
}
