//
//  LabelView.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-21.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import UIKit

struct LayoutedLabel: Codable, Hashable {
	let markerHash: Int
	let aabb: Aabb
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(markerHash)
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
	
	static func < (lhs: LabelMarker, rhs: LabelMarker) -> Bool {
		let lhsScore = lhs.rank - (lhs.kind == .Region ? 1 : 0)	// Value regions one step higher
		let rhsScore = rhs.rank - (rhs.kind == .Region ? 1 : 0)
		return lhsScore <= rhsScore
	}
}

class Label {
	let view: UILabel
	var ownerHash: RegionHash
	
	init() {
		view = UILabel()
		view.isHidden = true
		view.frame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 30.0)
		view.preferredMaxLayoutWidth = 200.0
		view.lineBreakMode = .byWordWrapping
		view.numberOfLines = 2
//		view.adjustsFontSizeToFitWidth = true
		
		ownerHash = 0
	}
}

class LabelView: UIView {
	static let s_maxLabels = 20
	var poiPrimitives: [Int : LabelMarker] = [:]
	var poiLabels: [Label] = []
	
	override func awakeFromNib() {
		for _ in 0 ..< LabelView.s_maxLabels {
			let newLabel = Label()
			poiLabels.append(newLabel)
			addSubview(newLabel.view)
		}
	}
	
	func buildPoiPrimitives(withVisibleContinents continents: GeoContinentMap,
													countries: GeoCountryMap,
													provinces: GeoProvinceMap) {
		
		// Collect a flat list of all POIs and their hash keys
		let continentPois = continents.flatMap { $0.value.places }
		let countryPois = countries.flatMap { $0.value.places }
		let provincePois = provinces.flatMap { $0.value.places }
		let allPois = continentPois + countryPois + provincePois
		let allPoiPrimitives = allPois.map { ($0.hashValue, LabelMarker(for: $0)) }
		
		// Insert them into the primitive dictionary, ignoring any later duplicates
		self.poiPrimitives = Dictionary(allPoiPrimitives, uniquingKeysWith: { (l, r) in print("Inserting bad"); return l })
	}
	
	func updatePrimitives<T:GeoNode & GeoPlaceContainer>(for node: T, with subRegions: Set<T.SubType>)
		where T.SubType: GeoPlaceContainer  {
		for poi in node.places {
			poiPrimitives.removeValue(forKey: poi.hashValue)
		}
		
		let subRegionPois = subRegions.flatMap { $0.places }
		let hashedPrimitives = subRegionPois.map {
			($0.hashValue, LabelMarker(for: $0))
		}
		poiPrimitives.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in print("Replacing"); return l })
	}
	
	func updateLabels(for activePoiHashes: Set<Int>, inArea focus: Aabb, atZoom zoom: Float, projection project: (Vertex) -> CGPoint) {
		// √ Create a QuadTree<LabelHash> (yes, per frame - we're only doing insertions, and there is nothing to learn from the previous layout frame)
		// x Copy label frame size into marker when binding
		// $ Reject labels that collide with a higher-prio label and keep selecting until pool is full
		// $ Teach poiPrimitives how to cycle down through anchor points
		// $ Teach poiPrimitives how to give their aabb based on anchor point, margins and radial offset (insert aabb on the primitive when binding the label)
		// $ Sort the poiPrimitives by priority
		// $ For each primitive
		//	$ query the qtree for the incoming label - intersect the results against the label aabb
		//  $ if no collision, insert the label into the tree
		//  $ if collision, try the other orientations
		// ------- it might be that this is enough; stop here and evaluate, because the next step may be O(n2) ------
		// ------- well actually, if a label can't fit in any of its four direction, the density in this region is probably too high; spend time on rebinding to another marker instead ------
		// ------- also, this layout should be done in prepareFrame so we only bind labels that will actually fit somewhere ------
		// ------- skip the prefix slicing, just pull labels until the pool is full ------
		//  $ if no other orientation works, take the list of NE collisions
		//		$ get the aabb of their next anchor, and see if all of them can be moved out of the way
		//		$ if so, remove them from the qtree and insert them in their new places
		//		$ if not, take the list of SE collisions and try agaig
		//  $ if a label cannot be inserted, unbind it and take another label in the next frame
		
		// Pick out the top markers for display
		let activeMarkers = poiPrimitives.values.filter { activePoiHashes.contains($0.ownerHash) }
		let visibleMarkers = activeMarkers.filter { boxContains(focus, $0.worldPos) }
		let unlimitedMarkers = visibleMarkers.filter { zoomFilter($0, zoom) }
		let prioritizedMarkers = unlimitedMarkers.sorted(by: <)

		// Collision detection structure for current view
		let screen = UIScreen.main.bounds // $ Fix
		var labelQuadTree = QuadTree<LayoutedLabel>(minX: Float(screen.minX), minY: Float(screen.minY), maxX: Float(screen.maxX), maxY: Float(screen.maxY), maxDepth: 9)
		
		// $ Do the layout (marker ID + anchor selection)
		
		var layoutedMarkers: [Int: LayoutedLabel] = [:]
		for marker in prioritizedMarkers {
			let origin = project(marker.worldPos)
			let size = labelSize(forMarker: marker)
			let rect = Aabb(loX: Float(origin.x), loY: Float(origin.y), hiX: Float(origin.x + size.width), hiY: Float(origin.y + size.height))
			
			let closeLabels = labelQuadTree.query(search: rect)
			let overlap = closeLabels.first { boxIntersects($0.aabb, rect) }
			if overlap != nil { continue }
				
			let layoutNode = LayoutedLabel(markerHash: marker.ownerHash, aabb: rect)
			labelQuadTree.insert(value: layoutNode, region: rect, warnOutside: false)
			layoutedMarkers[layoutNode.markerHash] = layoutNode	// $ Does LayoutNode need to include its markerHash?
			if layoutedMarkers.count > LabelView.s_maxLabels {
				break
			}
		}
		
		// Free up any labels whose markers are no longer on screen
		_ = poiLabels
			.filter({ $0.ownerHash != 0 && layoutedMarkers[$0.ownerHash] == nil })
			.map(unbindLabel)
		
		// # Bind markers without a label to a free label, break when no free label can be found
		
		// # Now we have a list of markers and labels - project them into place
		
		// $ for every markersToShow
		//  $ take the label size by name/font from the marker
		//  $ calculate AABB offset from NE anchor
		// 	$ query qtree for intersections with AABB, and do proper intersection.
		//	$ if any intersection, skip the marker
		//	$ if no intersection, bind the marker to any free label
		//	$ if no free label can be found, exit
		
		// $ step 2
		// $ if any intersection, change anchor, recalc AABB, and try again
		
		// Bind new markers into free labels
		for markerHash in layoutedMarkers.keys {
			guard poiLabels.first(where: { $0.ownerHash == markerHash }) == nil else { continue }	// $ Checks that the label is bound to a marker, unnecessary
			guard let freeLabel = poiLabels.first(where: { $0.ownerHash == 0 }) else { break }		// $ Finds a free label
			
			bindLabel(freeLabel, to: poiPrimitives[markerHash]!)
		}
		
		for label in poiLabels {
			guard label.ownerHash != 0 else { continue }
			let labelRect = layoutedMarkers[label.ownerHash]!.aabb	// $ Shitty layout
			label.view.frame = CGRect(x: CGFloat(labelRect.minX),
																y: CGFloat(labelRect.minY),
																width: CGFloat(labelRect.maxX - labelRect.minX),
																height: CGFloat(labelRect.maxY - labelRect.minY))
		}
	}
	
	func zoomFilter(_ marker: LabelMarker, _ zoom: Float) -> Bool {
		if marker.kind == .Region {
			// Region markers should go away after we've zoomed "past" them
			switch marker.rank {
			case 0: return zoom < 5.0
			case 1: return zoom < 10.0
			default: return true
			}
		} else {
			return true
		}
	}
	
	func renderLabels() {
		// $ Suppress immediate layout, layout after the frame is done
	}
	
	func labelSize(forMarker marker: LabelMarker) -> CGSize {
		let font: UIFont
		switch marker.kind {
			case .Region:
				switch marker.rank {
				case 0: font = .boldSystemFont(ofSize: 20.0)	// $ Move to stylesheet
				case 1: font = .boldSystemFont(ofSize: 16.0)
				default: font = .boldSystemFont(ofSize: 12.0)
				}
			case .Capital: font = .systemFont(ofSize: 13.0)
			case .City: font = .systemFont(ofSize: 11.0)
			case .Town: font = .systemFont(ofSize: 9.0)
		}
		
		let rect = (marker.name as NSString).boundingRect(with: CGSize(width: 200.0, height: 30.0),
																											options: .usesLineFragmentOrigin,
																											attributes: [.font: font],
																											context: nil)
		return rect.size
	}
	
	func bindLabel(_ label: Label, to marker: LabelMarker) {
		label.ownerHash = marker.ownerHash
		label.view.isHidden = false
		
		let alignment: NSTextAlignment
		let textColor: UIColor
		let strokeColor: UIColor
		let strokeWidth: CGFloat
		
		switch marker.kind {
		case .Region:
			textColor = .darkGray
			strokeColor = .white
			strokeWidth = -2.0
			alignment = .center
		default:
			textColor = .white
			strokeColor = .darkGray
			strokeWidth = -4.0
			alignment = .left
		}
		
		switch marker.kind {
		case .Region:
			switch marker.rank {
			case 0: label.view.font = .boldSystemFont(ofSize: 20.0)	// $ Move to stylesheet
			case 1: label.view.font = .boldSystemFont(ofSize: 16.0)
			default: label.view.font = .boldSystemFont(ofSize: 12.0)
			}
		case .Capital: label.view.font = .systemFont(ofSize: 13.0)
		case .City: label.view.font = .systemFont(ofSize: 11.0)
		case .Town: label.view.font = .systemFont(ofSize: 9.0)
		}
		 
		let strokeAttribs: [NSAttributedString.Key: Any] =
			[.strokeColor: strokeColor,
			 .foregroundColor: textColor,
			 .strokeWidth: strokeWidth]
		
		label.view.textAlignment = alignment
		label.view.attributedText = NSAttributedString(string: marker.name, attributes: strokeAttribs)
//		label.view.backgroundColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.4)
	}
	
	func unbindLabel(_ label: Label) {
		label.ownerHash = 0
		label.view.isHidden = true
	}
}
