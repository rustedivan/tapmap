//
//  RegionOutlineView.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-16.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa

class RegionOutlineView: NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate {
	var countries: GeoFeatureCollection!
	var regions: GeoFeatureCollection!
	
	override func awakeFromNib() {
		delegate = self
		dataSource = self
	}
	
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		if let feature = item as? GeoFeature {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") {
				return feature.name
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(feature.totalVertexCount()) vertices"
			}
		} else if let polygon = item as? GeoPolygon {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				if polygon.interiorRings.isEmpty {
					return "Simple (\(polygon.totalVertexCount()) vertices)"
				} else {
					return "Complex (\(polygon.totalVertexCount()) vertices, \(polygon.interiorRings.count) hole(s))"
				}
			}
		}
		return ""
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return countries?.features.count ?? 0
		} else if let feature = item as? GeoFeature {
			switch feature.level {
			case .Country: // Find the number of region-features that has `feature` as its admin
				let countryRegions = regions.features.filter {
					$0.admin == feature.admin
				}
				return countryRegions.count
			case .Region: // Return the number of polygons in the region
				return feature.polygons.count
			}
		} else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return !(item is GeoPolygon)
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			let countrySet = countries.features
			let countryIndex = countrySet.index(countrySet.startIndex, offsetBy: index)
			return countrySet[countryIndex]
		} else if let feature = item as? GeoFeature, feature.level == .Country {
			let regionSet = regions.features.filter {
				$0.admin == feature.admin
			}
			let regionIndex = regionSet.index(regionSet.startIndex, offsetBy: index)
			return regionSet[regionIndex]
		} else if let feature = item as? GeoFeature, feature.level == .Region {
			return feature.polygons[index]
		}
		return 0
	}
}
