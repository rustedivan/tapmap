//
//  LabelLayout.swift
//  tapmap
//
//  Created by Ivan Milles on 2021-01-16.
//  Copyright © 2021 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry
import UIKit.UIScreen

enum LayoutAnchor {
	case NE
	case SE
	case NW
	case SW
	case Center
	
	var next: LayoutAnchor? {
		switch self {
			case .NE: return .SE
			case .SE: return .NW
			case .NW: return .SW
			case .SW: return nil
			case .Center: return nil
		}
	}
}

struct LabelMarker: Comparable {
	let name: String
	let ownerHash: Int
	let worldPos: Vertex
	let kind: GeoPlace.Kind
	let rank: Int
	
	init(for poi: GeoPlace) {
		name = poi.name
		ownerHash = poi.hashValue
		worldPos = poi.location
		kind = poi.kind
		rank = poi.rank
	}
	
	var displayText: NSString {
		return ((kind == .Region) ? name.uppercased() : name) as NSString
	}
	
	static func < (lhs: LabelMarker, rhs: LabelMarker) -> Bool {
		let lhsScore = lhs.rank - (lhs.kind == .Region ? 1 : 0)	// Value regions one step higher
		let rhsScore = rhs.rank - (rhs.kind == .Region ? 1 : 0)
		return lhsScore < rhsScore
	}
}

// $ Can split out Codable into extension on QuadTree
struct LabelPlacement: Codable, Hashable {
	enum CodingKeys: CodingKey {
		case aabb
	}
	var markerHash: Int = 0
	let aabb: Aabb
	var anchor: LayoutAnchor = .NE
	var debugName: String = "Unknown"
	
	init(markerHash: Int, aabb: Aabb, anchor: LayoutAnchor, debugName: String) {
		self.markerHash = markerHash
		self.aabb = aabb
		self.anchor = anchor
		self.debugName = debugName
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(markerHash)
	}
}

typealias MeasureFunction = (LabelMarker) -> (w: Float, h: Float)
typealias LabelLayout = [Int : LabelPlacement]

class LabelLayoutEngine {
	let maxLabels: Int
	let space: Aabb
	let measure: MeasureFunction
	var labelMargin: Float = 3.0
	var labelDistance: Float = 2.0
	var orderedLayout: [LabelPlacement] = []
	var labelSizeCache: [Int : (w: Float, h: Float)] = [:]	// $ Limit size of this
	
	init(maxLabels: Int, space: Aabb, measure: @escaping MeasureFunction) {
		self.maxLabels = maxLabels
		self.space = space
		self.measure = measure
	}
	
	// $ Re-implement zoom culling as a 3D box sweeping through point cloud
	
	func layoutLabels(markers: [Int: LabelMarker],
										projection project: (Vertex) -> CGPoint) -> (layout: LabelLayout, removed: [Int]) {
		// Collision detection structure for screen-space layout
		var labelQuadTree = QuadTree<LabelPlacement>(minX: space.minX,
																								 minY: space.minY,
																								 maxX: space.maxX,
																								 maxY: space.maxY,
																								 maxDepth: 6)
		var workingSet = markers
		var removedFromLayout: [Int] = []
		// Move and insert the previously placed labels in their established order
		for (i, placement) in orderedLayout.enumerated() {
			let marker = workingSet[placement.markerHash]!

			let result = layoutLabel(marker: marker, in: labelQuadTree, startAnchor: placement.anchor, project: project)
			
			if let (labelBox, layoutBox, anchor) = result {
				let reprojectedPlacement = LabelPlacement(markerHash: marker.ownerHash, aabb: labelBox, anchor: anchor, debugName: marker.name)
				labelQuadTree.insert(value: reprojectedPlacement, region: layoutBox, clipToBounds: true)
				orderedLayout[i] = LabelPlacement(markerHash: placement.markerHash, aabb: labelBox, anchor: anchor, debugName: marker.name)
			} else {
				removedFromLayout.append(placement.markerHash)
			}
			workingSet.removeValue(forKey: placement.markerHash)
		}
		
		removedFromLayout.forEach { removeFromLayout($0) }
		
		// Layout new incoming markers
		let markersToLayout = Array(workingSet.values).sorted(by: <)
		for marker in markersToLayout {
			guard orderedLayout.count < maxLabels else { break }
			
			let startAnchor: LayoutAnchor = (marker.kind == .Region ? .Center : .NE)	// Choose starting layout anchor
			let result = layoutLabel(marker: marker, in: labelQuadTree, startAnchor: startAnchor, project: project)
			if let (labelBox, layoutBox, anchor) = result {
				let placement = LabelPlacement(markerHash: marker.ownerHash, aabb: labelBox, anchor: anchor, debugName: marker.name)	// Unpadded aabb for layout
				labelQuadTree.insert(value: placement, region: layoutBox, clipToBounds: true)							// Padded aabb for collision
				orderedLayout.append(placement)
			}
		}

		let layoutEntries = orderedLayout.map { ($0.markerHash, $0) }
		let layout: LabelLayout = Dictionary(uniqueKeysWithValues: layoutEntries)
		return (layout: layout, removed: removedFromLayout)
	}
	
	func layoutLabel(marker: LabelMarker, in layout: QuadTree<LabelPlacement>, startAnchor: LayoutAnchor, project: (Vertex) -> CGPoint) -> (labelBox: Aabb, layoutBox: Aabb, anchor: LayoutAnchor)? {
		var anchor: LayoutAnchor? = startAnchor
		let origin = project(marker.worldPos)
		let size = labelSize(forMarker: marker)
		
		while anchor != nil {
			let aabb = placeLabel(width: size.w, height: size.h, at: origin, anchor: anchor!, distance: labelDistance)
			let paddedAabb = padAabb(aabb, margin: labelMargin)
			
			let closeLabels = layout.query(search: paddedAabb)
			let canPlaceLabel = closeLabels.allSatisfy { boxIntersects($0.aabb, paddedAabb) == false }
			if canPlaceLabel {
				return (labelBox: aabb, layoutBox: paddedAabb, anchor!)
			} else {
				anchor = anchor?.next
			}
		}
		return nil
	}
	
	func removeFromLayout(_ markerHash: Int) {
		let i = orderedLayout.firstIndex { $0.markerHash == markerHash }!
		orderedLayout.remove(at: i)
	}
	
	func labelSize(forMarker marker: LabelMarker) -> (w: Float, h: Float) {
		if let cachedSize = labelSizeCache[marker.ownerHash] {
			return cachedSize
		} else {
			let m = measure(marker)
			labelSizeCache[marker.ownerHash] = m
			return m
		}
	}
}

fileprivate func placeLabel(width: Float, height: Float, at screenPos: CGPoint, anchor: LayoutAnchor, distance d: Float) -> Aabb {
	let markerPos = Vertex(Float(screenPos.x), Float(screenPos.y))
	let lowerLeft: Vertex
	switch anchor {
		case .NE: lowerLeft = markerPos + Vertex(+d, -d) + Vertex(0.0, -height)
		case .SE: lowerLeft = markerPos + Vertex(+d, +d) + Vertex(0.0, 0.0)
		case .NW: lowerLeft = markerPos + Vertex(-d, -d) + Vertex(-width, -height)
		case .SW: lowerLeft = markerPos + Vertex(-d, +d) + Vertex(-width, 0.0)
		case .Center: lowerLeft = markerPos + Vertex(-width / 2.0, -height / 2.0)
	}

	return Aabb(loX: floor(lowerLeft.x), loY: floor(lowerLeft.y),
							hiX: ceil(lowerLeft.x + width), hiY: ceil(lowerLeft.y + height))
}

fileprivate func padAabb(_ aabb: Aabb, margin: Float) -> Aabb {
	return Aabb(loX: aabb.minX - margin, loY: aabb.minY - margin, hiX: aabb.maxX + margin, hiY: aabb.maxY + margin)
}
