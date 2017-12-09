//
//  RegionOutlineView.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-16.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa

class RegionOutlineView: NSOutlineView, NSOutlineViewDataSource, NSOutlineViewDelegate {
	var world: [GeoFeatureCollection]?
	
	override func awakeFromNib() {
		delegate = self
		dataSource = self
	}
	
	func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
		if let continent = item as? GeoFeatureCollection {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") {
				return continent.name
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
				return "\(continent.features.count) countries"
			}
        } else if let country = item as? GeoFeature {
            if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") {
                return country.name
            } else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Vertices") {
                return "\(country.totalVertexCount()) vertices"
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
		guard let world = world else { return 0 }
		if item == nil {
			return world.count
		} else {
			if let region = item as? GeoFeatureCollection {
				return region.features.count
            } else if let country = item as? GeoFeature {
                return country.polygons.count
            }
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return !(item is GeoPolygon)
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return world![index]
		} else if let continent = item as? GeoFeatureCollection {
            return continent.features[index]
        } else if let country = item as? GeoFeature {
            return country.polygons[index]
        }
		return 0
	}
}
