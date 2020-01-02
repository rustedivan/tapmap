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
	var worldTree: QuadTree<RegionBounds>!
	
	func cullWorldTree(focus: Aabb) -> Set<Int> {
		func intersects(_ a: Aabb, _ b: Aabb) -> Bool {
			return !( a.minX >= b.maxX ||
								a.maxX <= b.minX ||
								a.minY >= b.maxY ||
								a.maxY <= b.minY)
		}
		
		let roughlyVisible = worldTree.query(search: focus)
		let finelyVisible = roughlyVisible.filter { intersects($0.bounds, focus) }
		let visibleHashes = Set(finelyVisible.map { $0.regionHash })
		return visibleHashes
	}
	
	func buildWorldTree(withWorld geoWorld: GeoWorld, userState: UserState) {
		worldTree = QuadTree(minX: -180.0, minY: -90.0, maxX: 181.0, maxY: 90.0, maxDepth: 6)
		for continent in geoWorld.children {
			let continentBox = RegionBounds(regionHash: continent.hashValue, bounds: continent.geometry.aabb)
			worldTree.insert(value: continentBox, region: continentBox.bounds)
			if userState.placeVisited(continent) {
				for country in continent.children {
					let countryBox = RegionBounds(regionHash: country.hashValue, bounds: country.geometry.aabb)
					worldTree.insert(value: countryBox, region: countryBox.bounds)
					if userState.placeVisited(country) {
						for region in country.children {
							if userState.placeVisited(continent) {
								let regionBox = RegionBounds(regionHash: region.hashValue, bounds: region.geometry.aabb)
								worldTree.insert(value: regionBox, region: regionBox.bounds)
							}
						}
					}
				}
			}
		}
	}
	
	func updateTree(replace parent: GeoContinent, with children: Set<GeoCountry>) {
		worldTree.remove(hashValue: parent.hashValue)
		for child in children {
			let countryBox = RegionBounds(regionHash: child.hashValue, bounds: child.geometry.aabb)
			worldTree.insert(value: countryBox, region: countryBox.bounds)
		}
	}

	func updateTree(replace parent: GeoCountry, with children: Set<GeoRegion>) {
		worldTree.remove(hashValue: parent.hashValue)
		for child in children {
			let regionBox = RegionBounds(regionHash: child.hashValue, bounds: child.geometry.aabb)
			worldTree.insert(value: regionBox, region: regionBox.bounds)
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
