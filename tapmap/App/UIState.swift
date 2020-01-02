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
	var worldTree: QuadTree!
	
	func cullWorldTree(focus: Aabb) -> Set<Int> {
		let visible = worldTree.query(search: focus)
		return visible
	}
	
	func buildWorldTree(withWorld geoWorld: GeoWorld, userState: UserState) {
		worldTree = QuadTree(minX: -180.0, minY: -90.0, maxX: 181.0, maxY: 90.0, maxDepth: 6)
		for continent in geoWorld.children {
			worldTree.insert(value: continent.hashValue, region: continent.geometry.aabb)
			if userState.placeVisited(continent) {
				for country in continent.children {
					worldTree.insert(value: country.hashValue, region: country.geometry.aabb)
					if userState.placeVisited(country) {
						for region in country.children {
							if userState.placeVisited(continent) {
								worldTree.insert(value: region.hashValue, region: region.geometry.aabb)
							}
						}
					}
				}
			}
		}
	}
	
	func updateTree(replace parent: GeoContinent, with children: Set<GeoCountry>) {
		worldTree.remove(value: parent.hashValue)
		for child in children {
			worldTree.insert(value: child.hashValue, region: child.geometry.aabb)
		}
	}

	func updateTree(replace parent: GeoCountry, with children: Set<GeoRegion>) {
		worldTree.remove(value: parent.hashValue)
		for child in children {
			worldTree.insert(value: child.hashValue, region: child.geometry.aabb)
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
func debugRenderTree(_ tree: QuadTree, at focus: Aabb) {
	debugQuadNode(tree.root, at: focus)
	_ = DebugRenderer.shared.addTransientQuad(for: focus, alpha: 1.0, name: "Focus", color: .red)
}

func debugQuadNode(_ node: QuadNode, at focus: Aabb) {
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
