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

	func placeVisited<T:Hashable>(_ p: T) -> Bool {
		return visitedPlaces[p.hashValue] ?? false
	}
	
	func visitPlace<T:Hashable>(_ p: T) {
		visitedPlaces[p.hashValue] = true
	}
}
