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
	var worldQuadTree: WorldTree!								// For spatial lookups
	var visibleRegionHashes: Set<Int> = Set()		// Cache of currently visible regions
	var delegate: UIStateDelegate!
	
	func cullWorldTree(focus: Aabb) {
		// Update region cache
		visibleRegionHashes = queryWorldTree(focus: focus)
		delegate.visibilityDidChange(visibleSet: visibleRegionHashes)
	}
	
	func queryWorldTree(focus: Aabb) -> Set<Int> {
		func intersects(_ a: Aabb, _ b: Aabb) -> Bool {
			return !( a.minX >= b.maxX ||
								a.maxX <= b.minX ||
								a.minY >= b.maxY ||
								a.maxY <= b.minY)
		}
		
		let roughlyFocused = worldQuadTree.query(search: focus)
		let finelyFocused = roughlyFocused.filter { intersects($0.bounds, focus) }
		
		return Set(finelyFocused.map { $0.regionHash })
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

protocol UIStateDelegate {
	func visibilityDidChange(visibleSet: Set<RegionHash>)
}
