//
//  UIState.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-03-22.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class UIState {
	private var selectedRegionHash: Int = 0
	
	func selectRegion<T:GeoIdentifiable>(_ region: T) {
		selectedRegionHash = region.hashValue
	}
	
	func selected<T:GeoIdentifiable>(_ object: T) -> Bool {
		return selectedRegionHash == object.hashValue
	}
	
	func selected(_ hashValue: Int) -> Bool {
		return selectedRegionHash == hashValue
	}
	
	func clearSelection() {
		selectedRegionHash = 0
	}
}
