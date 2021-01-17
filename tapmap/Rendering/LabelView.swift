//
//  LabelView.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-21.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import UIKit

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
		
		ownerHash = 0
	}
}

class LabelView: UIView {
	static let s_maxLabels = 20
	var poiPrimitives: [Int : LabelMarker] = [:]
	var poiLabels: [Label] = []
	var layoutEngine = LabelLayoutEngine(maxLabels: s_maxLabels)
	
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
		// Pick out the top markers for display
		let activeMarkers = poiPrimitives.values.filter { activePoiHashes.contains($0.ownerHash) }
		let visibleMarkers = activeMarkers.filter { zoomFilter($0, zoom) && boxContains(focus, $0.worldPos) }
		
		// Layout up to s_maxLabels
		let layout = layoutEngine.layoutLabels(visibleMarkers: visibleMarkers, projection: project)
		
		bindLabelsToNewMarkers(layout: layout)
		
		for label in poiLabels {
			guard let labelRect = layout[label.ownerHash]?.aabb else { continue }
			label.view.frame = CGRect(x: CGFloat(labelRect.minX),
																y: CGFloat(labelRect.minY),
																width: CGFloat(labelRect.maxX - labelRect.minX),
																height: CGFloat(labelRect.maxY - labelRect.minY))
			// $ Align text with anchor direction
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
	
	func bindLabelsToNewMarkers(layout: [Int : LabelPlacement]) {
		// Free up any labels whose markers are no longer on screen
		_ = poiLabels
			.filter({ $0.ownerHash != 0 && layout[$0.ownerHash] == nil })
			.map(unbindLabel)
		
		let boundLabels = Set<Int>(poiLabels
																.filter { $0.ownerHash != 0 }
																.map { $0.ownerHash })
		
		// Find free labels and unbound markers
		var freeLabels = poiLabels.filter { boundLabels.contains($0.ownerHash) == false}
		let unboundMarkers = layout.filter { boundLabels.contains($0.key) == false }
		
		// Bind new markers into free labels
		for markerHash in unboundMarkers.keys {
			let freeLabel = freeLabels.popLast()!
			bindLabel(freeLabel, to: poiPrimitives[markerHash]!)
		}
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
	}
	
	func unbindLabel(_ label: Label) {
		label.ownerHash = 0
		label.view.isHidden = true
	}
}
