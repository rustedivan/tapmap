//
//  UserState.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-11-14.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation

class UserState {
	var openedRegions: [Int : Bool] = [:]

	func regionOpened(r: GeoRegion) -> Bool {
		return openedRegions[r.hashValue] ?? false
	}
	
	func openRegion(_ r: GeoRegion) {
		openedRegions[r.hashValue] = true
	}
}
