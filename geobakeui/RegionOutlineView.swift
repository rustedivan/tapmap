//
//  RegionOutlineView.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-16.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa

class RegionOutlineView: NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate {
	var world: GeoWorld? = nil
	
	override func awakeFromNib() {
		delegate = self
		dataSource = self
	}
	
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {

		if let item = item as? GeoContinent {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") {
				return item.name
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(item.borderVertices.count) vertices"
			}
		} else if let item = item as? GeoRegion {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") {
				return item.name
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(item.features.count) features"
			}
		} else if let item = item as? GeoFeature {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(item.vertexRange.start) -> \(item.vertexRange.start + item.vertexRange.count)"
			}
		}
		return ""
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		guard let world = world else { return 0 }
		if item == nil {
			return world.continents.count
		} else {
			if let continent = item as? GeoContinent {
				return continent.regions.count
			}
			
			if let region = item as? GeoRegion {
				return region.features.count
			}
			
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if let _ = item as? GeoFeature {
			return false
		} else {
			return true
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return world!.continents[index]
		} else  {
			if let continent = item as? GeoContinent {
				return continent.regions[index]
			}
			
			if let region = item as? GeoRegion {
				return region.features[index]
			}
			
			Swift.print("No childen of \(String(describing: item))")
			return 0
		}
	}
}
