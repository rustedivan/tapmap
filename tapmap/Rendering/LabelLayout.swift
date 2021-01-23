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

func placeLabel(width: Float, height: Float, at screenPos: CGPoint, anchor: LayoutAnchor) -> Aabb {
	let radialDistance: Float = 2.0
	let markerPos = Vertex(Float(screenPos.x), Float(screenPos.y))
	let lowerLeft: Vertex
	switch anchor {
		case .NE: lowerLeft = markerPos + Vertex(+radialDistance, -radialDistance) + Vertex(0.0, -height)
		case .SE: lowerLeft = markerPos + Vertex(+radialDistance, +radialDistance) + Vertex(0.0, 0.0)
		case .NW: lowerLeft = markerPos + Vertex(-radialDistance, -radialDistance) + Vertex(-width, -height)
		case .SW: lowerLeft = markerPos + Vertex(-radialDistance, +radialDistance) + Vertex(-width, 0.0)
		case .Center: lowerLeft = markerPos + Vertex(-width / 2.0, -height / 2.0)
	}


	return Aabb(loX: lowerLeft.x, loY: lowerLeft.y,
							hiX: lowerLeft.x + width, hiY: lowerLeft.y + height)
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
	
	var font: UIFont {
		switch kind {
			case .Region:
				switch rank {
					case 0: return UIFont(name: "HelveticaNeue-Bold", size: 20.0)!	// $ Move to stylesheet
					case 1: return UIFont(name: "HelveticaNeue-Bold", size: 16.0)!
					default: return UIFont(name: "HelveticaNeue-Bold", size: 12.0)!
				}
			case .Capital: return UIFont(name: "HelveticaNeue-Bold", size: 14.0)!
			case .City: return UIFont(name: "HelveticaNeue-Bold", size: 12.0)!
			case .Town: return UIFont(name: "HelveticaNeue-Bold", size: 10.0)!
		}
	}
	
	static func < (lhs: LabelMarker, rhs: LabelMarker) -> Bool {
		let lhsScore = lhs.rank - (lhs.kind == .Region ? 1 : 0)	// Value regions one step higher
		let rhsScore = rhs.rank - (rhs.kind == .Region ? 1 : 0)
		
		let lVal = (lhsScore, lhs.ownerHash)
		let rVal = (rhsScore, rhs.ownerHash)
		
		return lVal < rVal
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
	var labelSizeCache: [Int : (w: Float, h: Float)] = [:]	// $ Limit size of this
	
	init(maxLabels: Int) {
		self.maxLabels = maxLabels
		// Collision detection structure for screen-space layout
	}
	
	// $ Re-implement zoom culling as a 3D box sweeping through point cloud
	
	func layoutLabels(labeledMarkers: [LabelMarker],
										unlabeledMarkers: [LabelMarker],
										projection project: (Vertex) -> CGPoint) -> [Int : LabelPlacement] {
		let newCandidates = unlabeledMarkers.sorted(by: <)
		let prioritizedMarkers = labeledMarkers + newCandidates
		let workingSet = prioritizedMarkers.prefix(maxLabels * 2)	// Take enough markers to give each label two candidates
		
		let screen = UIScreen.main.bounds
		var labelQuadTree = QuadTree<LabelPlacement>(minX: Float(screen.minX),
																								 minY: Float(screen.minY),
																								 maxX: Float(screen.maxX),
																								 maxY: Float(screen.maxY),
																								 maxDepth: 6)
		
		let margin: Float = 3.0 // $ Stylesheet
		var layout: [Int : LabelPlacement] = [:]
		for marker in workingSet {
			var anchor: LayoutAnchor? = (marker.kind == .Region ? .Center : .NE)	// Choose starting layout anchor
			let origin = project(marker.worldPos)
			let size = labelSize(forMarker: marker)
			
			repeat {
				let aabb = placeLabel(width: size.w, height: size.h, at: origin, anchor: anchor!)
				let paddedAabb = Aabb(loX: aabb.minX - margin, loY: aabb.minY - margin, hiX: aabb.maxX + margin, hiY: aabb.maxY + margin)
				
				let closeLabels = labelQuadTree.query(search: paddedAabb)
				let canPlaceLabel = closeLabels.allSatisfy { boxIntersects($0.aabb, paddedAabb) == false }
				if canPlaceLabel
				{
					let layoutNode = LabelPlacement(markerHash: marker.ownerHash, aabb: aabb, anchor: anchor!)	// Use the unpadded aabb for the actual label
					labelQuadTree.insert(value: layoutNode, region: paddedAabb, clipToBounds: true)							// Use the padded aabb for collision detection
					layout[marker.ownerHash] = layoutNode
					break
				} else {
					anchor = anchor?.next
				}
			} while anchor != nil
			
			if layout.count >= maxLabels {
				break
			}
		}
		
		return layout
	}
	
	func labelSize(forMarker marker: LabelMarker) -> (w: Float, h: Float) {
		if let cachedSize = labelSizeCache[marker.ownerHash] {
			return cachedSize
		}
		
		let font = marker.font
		let size = marker.displayText.boundingRect(with: CGSize(width: 120.0, height: 120.0),
																											options: .usesLineFragmentOrigin,
																											attributes: [.font: font],
																											context: nil)
																											.size
		let wh = (w: Float(ceil(size.width)), h: Float(ceil(size.height)))
		labelSizeCache[marker.ownerHash] = wh
		return wh
	}
}
