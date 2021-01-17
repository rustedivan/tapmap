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
	
	var next: LayoutAnchor? {
		switch self {
			case .NE: return .SE
			case .SE: return .NW
			case .NW: return .SW
			case .SW: return nil
		}
	}
}

fileprivate func layout(width: Float, height: Float, at worldPos: Vertex, anchor: LayoutAnchor) -> Aabb {
	// $ Radial distance from Stylesheet
	return Aabb()
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
	
	var font: UIFont {
		switch kind {
			case .Region:
				switch rank {
				case 0: return .boldSystemFont(ofSize: 20.0)	// $ Move to stylesheet
				case 1: return .boldSystemFont(ofSize: 16.0)
				default: return .boldSystemFont(ofSize: 12.0)
				}
			case .Capital: return .systemFont(ofSize: 13.0)
			case .City: return .systemFont(ofSize: 11.0)
			case .Town: return .systemFont(ofSize: 9.0)
		}
	}
	
	static func < (lhs: LabelMarker, rhs: LabelMarker) -> Bool {
		let lhsScore = lhs.rank - (lhs.kind == .Region ? 1 : 0)	// Value regions one step higher
		let rhsScore = rhs.rank - (rhs.kind == .Region ? 1 : 0)
		return lhsScore <= rhsScore
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
	
	init(markerHash: Int, aabb: Aabb, anchor: LayoutAnchor) {
		self.markerHash = markerHash
		self.aabb = aabb
		self.anchor = anchor
	}
	func hash(into hasher: inout Hasher) {
		hasher.combine(markerHash)
	}
}

class LabelLayoutEngine {
	let maxLabels: Int
	var labelSizeCache: [Int : CGSize] = [:]
	
	init(maxLabels: Int) {
		self.maxLabels = maxLabels
	}
	
	func layoutLabels(visibleMarkers: [LabelMarker],
										projection project: (Vertex) -> CGPoint) -> [Int : LabelPlacement] {
		let prioritizedMarkers = visibleMarkers.sorted(by: <)
		let workingSet = prioritizedMarkers.prefix(maxLabels * 2)	// Take enough markers to give each label two candidates
		
		// Collision detection structure for screen-space layout
		let screen = UIScreen.main.bounds
		var labelQuadTree = QuadTree<LabelPlacement>(minX: Float(screen.minX),
																								 minY: Float(screen.minY),
																								 maxX: Float(screen.maxX),
																								 maxY: Float(screen.maxY),
																								 maxDepth: 9)
		
		var layout: [Int : LabelPlacement] = [:]
		
		for marker in workingSet {
			let origin = project(marker.worldPos)
			let size = labelSize(forMarker: marker)
			let aabb = Aabb(loX: Float(origin.x), loY: Float(origin.y),
											hiX: Float(origin.x + size.width), hiY: Float(origin.y + size.height))
			
			let closeLabels = labelQuadTree.query(search: aabb)
			if closeLabels.allSatisfy({ boxIntersects($0.aabb, aabb) == false })
			{
				let layoutNode = LabelPlacement(markerHash: marker.ownerHash, aabb: aabb, anchor: LayoutAnchor.NE)
				labelQuadTree.insert(value: layoutNode, region: aabb, warnOutside: false)
				layout[layoutNode.markerHash] = layoutNode
			}
			
			if layout.count >= maxLabels {
				break
			}
		}
		
		return layout
	}
	
	func labelSize(forMarker marker: LabelMarker) -> CGSize {
		if let cachedSize = labelSizeCache[marker.ownerHash] {
			return cachedSize
		}
		
		let font = marker.font
		let size = (marker.name as NSString).boundingRect(with: CGSize(width: 200.0, height: 30.0),
																											options: .usesLineFragmentOrigin,
																											attributes: [.font: font],
																											context: nil)
																											.size
		labelSizeCache[marker.ownerHash] = size
		return size
	}
}
