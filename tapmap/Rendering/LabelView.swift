//
//  LabelView.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-21.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import UIKit

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

class LabelView: UIView {
	static let s_maxLabels = 20
	var poiPrimitives: [Int: LabelMarker] = [:]
	var poiLabels: [UILabel] = []
	
	override func awakeFromNib() {
		for _ in 0 ..< LabelView.s_maxLabels {
			let newLabel = UILabel()
			newLabel.tag = 0
			newLabel.isHidden = true
			newLabel.frame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 30.0)
			newLabel.preferredMaxLayoutWidth = 200.0
			newLabel.lineBreakMode = .byWordWrapping
			newLabel.numberOfLines = 2
			newLabel.adjustsFontSizeToFitWidth = true
			
			poiLabels.append(newLabel)
			addSubview(newLabel)
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
	
	func updateLabels(for activePoiHashes: Set<Int>, inArea focus: Aabb, atZoom zoom: Float) {
		// Pick out the top-ten markers for display
		let activeMarkers = poiPrimitives.values.filter { activePoiHashes.contains($0.ownerHash) }
		let visibleMarkers = activeMarkers.filter { boxContains(focus, $0.worldPos) }
		let unlimitedMarkers = visibleMarkers.filter { zoomFilter($0, zoom) }
		let prioritizedMarkers = unlimitedMarkers.sorted(by: <)
		let markersToShow = prioritizedMarkers.prefix(LabelView.s_maxLabels)
		let hashesToShow = markersToShow.map { $0.ownerHash }
		
		// First free up any labels that no longer have active markers
		_ = poiLabels
			.filter({$0.tag != 0 && !hashesToShow.contains($0.tag)})
			.map(unbindLabel)
		
		// Bind new markers into free labels
		for marker in markersToShow {
			guard poiLabels.first(where: { $0.tag == marker.ownerHash }) == nil else {
				continue
			}
			guard let freeLabel = poiLabels.first(where: { $0.tag == 0 }) else {
				print("Marker \(marker.ownerHash) could not be bound to a free label")
				continue
			}
			
			bindLabel(freeLabel, to: marker)
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
	
	func renderLabels(projection project: (Vertex) -> CGPoint) {
		for label in poiLabels {
			guard let marker = poiPrimitives.values.first(where: { $0.ownerHash == label.tag }) else {
				continue
			}
			
			// Layout labels (region labels hang under the center, POI labels hang from their top-left)
			let screenPos = project(marker.worldPos)
			switch marker.kind {
			case .Region: label.center = screenPos
			default: label.frame.origin = screenPos
			}
		}
	}
	
	func bindLabel(_ label: UILabel, to marker: LabelMarker) {
		label.tag = marker.ownerHash
		label.isHidden = false
		
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
			case 0: label.font = .boldSystemFont(ofSize: 20.0)
			case 1: label.font = .boldSystemFont(ofSize: 16.0)
			default: label.font = .boldSystemFont(ofSize: 12.0)
			}
		case .Capital: label.font = .systemFont(ofSize: 13.0)
		case .City: label.font = .systemFont(ofSize: 11.0)
		case .Town: label.font = .systemFont(ofSize: 9.0)
		}
		 
		let strokeAttribs: [NSAttributedString.Key: Any] =
			[.strokeColor: strokeColor,
			 .foregroundColor: textColor,
			 .strokeWidth: strokeWidth]
		
		label.textAlignment = alignment
		label.attributedText = NSAttributedString(string: marker.name, attributes: strokeAttribs)
	}
	
	func unbindLabel(_ label: UILabel) {
		label.tag = 0
		label.isHidden = true
	}
}
