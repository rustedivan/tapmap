//
//  UIState.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-03-22.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class UIState {
	struct RegionBounds: Hashable {
		let regionHash: Int
		let bounds: Aabb
		func hash(into hasher: inout Hasher) {
			hasher.combine(regionHash)
		}
	}
	
	private var selectedRegionHash: Int = 0
	var worldQuadTree: QuadTree<RegionBounds>!	// For spatial lookups
	var visibleRegionHashes: Set<Int> = Set()		// Cache of currently visible regions
	
	func cullWorldTree(focus: Aabb) {
		func intersects(_ a: Aabb, _ b: Aabb) -> Bool {
			return !( a.minX >= b.maxX ||
								a.maxX <= b.minX ||
								a.minY >= b.maxY ||
								a.maxY <= b.minY)
		}
		
		let roughlyVisible = worldQuadTree.query(search: focus)
		let finelyVisible = roughlyVisible.filter { intersects($0.bounds, focus) }
		
		// Update region cache
		visibleRegionHashes = Set(finelyVisible.map { $0.regionHash })
	}
	
	func buildWorldTree(withWorld geoWorld: GeoWorld, userState: UserState) {
		worldQuadTree = QuadTree(minX: -180.0, minY: -90.0, maxX: 181.0, maxY: 90.0, maxDepth: 6)
		
		for (hash, continent) in userState.availableContinents {
			let continentBox = RegionBounds(regionHash: hash, bounds: continent.geometry.aabb)
			worldQuadTree.insert(value: continentBox, region: continentBox.bounds)
		}
		
		for (hash, country) in userState.availableCountries {
			let countryBox = RegionBounds(regionHash: hash, bounds: country.geometry.aabb)
			worldQuadTree.insert(value: countryBox, region: countryBox.bounds)
		}
		
		for (hash, region) in userState.availableRegions {
			let regionBox = RegionBounds(regionHash: hash, bounds: region.geometry.aabb)
			worldQuadTree.insert(value: regionBox, region: regionBox.bounds)
		}
	}
	
	func updateTree<T:GeoNode>(replace parent: T, with children: Set<T.SubType>) {
		worldQuadTree.remove(hashValue: parent.hashValue)
		for child in children {
			let countryBox = RegionBounds(regionHash: child.hashValue, bounds: child.geometry.aabb)
			worldQuadTree.insert(value: countryBox, region: countryBox.bounds)
		}
	}

	func updateTree(replace parent: GeoCountry, with children: Set<GeoRegion>) {
		worldQuadTree.remove(hashValue: parent.hashValue)
		for child in children {
			let regionBox = RegionBounds(regionHash: child.hashValue, bounds: child.geometry.aabb)
			worldQuadTree.insert(value: regionBox, region: regionBox.bounds)
		}
	}

	func selectRegion<T:GeoIdentifiable>(_ region: T) {
		selectedRegionHash = region.hashValue
		DebugRenderer.shared.moveSelection(region.aabb)
	}
	
	func selected<T:GeoIdentifiable>(_ object: T) -> Bool {
		return selectedRegionHash == object.hashValue
	}
	
	func selected(_ hashValue: Int) -> Bool {
		return selectedRegionHash == hashValue
	}
	
	func clearSelection() {
		selectedRegionHash = 0
		DebugRenderer.shared.moveSelection(Aabb.init())
	}
}

// MARK: Debug rendering
func debugRenderTree(_ tree: QuadTree<Int>, at focus: Aabb) {
	debugQuadNode(tree.root, at: focus)
	_ = DebugRenderer.shared.addTransientQuad(for: focus, alpha: 1.0, name: "Focus", color: .red)
}

func debugQuadNode(_ node: QuadNode<Int>, at focus: Aabb) {
	if case let .Node(bounds, values, tl, tr, bl, br) = node {
		let highlight =  !( focus.minX >= bounds.maxX ||
												focus.maxX <= bounds.minX ||
												focus.minY >= bounds.maxY ||
												focus.maxY <= bounds.minY)
		_ = DebugRenderer.shared.addTransientQuad(for: bounds, alpha: highlight ? 1.0 : 0.2, name: "Node", color: highlight ? .white : values.hashColor)
		debugQuadNode(tl, at: focus)
		debugQuadNode(tr, at: focus)
		debugQuadNode(bl, at: focus)
		debugQuadNode(br, at: focus)
	}
}
