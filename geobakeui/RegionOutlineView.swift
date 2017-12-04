//
//  RegionOutlineView.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-16.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa

class RegionOutlineView: NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate {
	var world: [GeoMultiFeature]? = nil
	
	override func awakeFromNib() {
		delegate = self
		dataSource = self
	}
	
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		if let item = item as? GeoMultiFeature {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") {
				return item.name
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(item.totalVertexCount()) vertices"
			}
		} else if let item = item as? GeoFeature {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(item.vertices.count) vertices"
			}
		}
		return ""
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		guard let world = world else { return 0 }
		if item == nil {
			return world.count
		} else {
			if let region = item as? GeoMultiFeature {
				return region.subFeatures.count + region.subMultiFeatures.count
			}
			
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return !(item is GeoFeature)
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return world![index]
		} else  {
			if let multiFeature = item as? GeoMultiFeature {
				// Treat index as mapping into subFeatures.concat(subMultiFeatures)
				let featuresCount = multiFeature.subFeatures.count
				let indexIntoSubMultiFeatures = index - featuresCount
				if index < featuresCount {
					return multiFeature.subFeatures[index]
				} else {
					return multiFeature.subMultiFeatures[indexIntoSubMultiFeatures]
				}
			}
		}
		return 0
	}
}
