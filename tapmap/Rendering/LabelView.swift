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
		view.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 30.0)
		view.preferredMaxLayoutWidth = 100.0
		view.lineBreakMode = .byWordWrapping
		view.numberOfLines = 2
		view.allowsDefaultTighteningForTruncation = true
		
		ownerHash = 0
	}
}

class LabelView: UIView {
	static let s_maxLabels = 50
	var poiPrimitives: [Int : LabelMarker] = [:]
	var poiLabels: [Label] = []
	var layoutEngine = LabelLayoutEngine(maxLabels: s_maxLabels)
	var labelAges: [Int : Double] = [:]	// $ Typealias the marker hash
	
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
		let activeMarkers = poiPrimitives.values.filter { activePoiHashes.contains($0.ownerHash) }
		let visibleMarkers = activeMarkers.filter { zoomFilter($0, zoom) && boxContains(focus, $0.worldPos) }
		let visibleMarkerHashes = Set<Int>(visibleMarkers.map { $0.ownerHash })
		
		
		let freeLabels = poiLabels.filter { $0.ownerHash == 0 || visibleMarkerHashes.contains($0.ownerHash)  == false}
		freeLabels.forEach { unbindLabel($0) }
		
		// Find new/unbound markers
		let boundLabelsHashes = Set<Int>(poiLabels
																.filter { $0.ownerHash != 0 }
																.map { $0.ownerHash })
		let boundMarkers = visibleMarkers
			.filter { boundLabelsHashes.contains($0.ownerHash) == true }
			.sorted { (lhs, rhs) -> Bool in
				labelAges[lhs.ownerHash]! < labelAges[rhs.ownerHash]!	// Older labels layouted before newer
			}
		let unboundMarkers = visibleMarkers
			.filter { boundLabelsHashes.contains($0.ownerHash) == false }
			.sorted(by: <)
		
		let markersToLayout = boundMarkers + unboundMarkers
		
		let layout = layoutEngine.layoutLabels(markers: markersToLayout,
																					 projection: project)
		let layoutContent = Set<Int>(layout.keys)
		let newLayoutEntries = unboundMarkers.filter { layoutContent.contains($0.ownerHash) }

		bindMarkers(newLayoutEntries, to: freeLabels)

		// Move all labels into place
		for label in poiLabels {
			guard let placement = layout[label.ownerHash] else {
				// Labes that could not be laid out should be unbound
				print("Warning: label for \(label.view.text) got knocked out of the layout.")
				if label.view.isHidden == false {
					unbindLabel(label)
				}
				continue
			}
			let labelRect = placement.aabb
			label.view.frame = CGRect(x: CGFloat(labelRect.minX),
																y: CGFloat(labelRect.minY),
																width: CGFloat(labelRect.maxX - labelRect.minX),
																height: CGFloat(labelRect.maxY - labelRect.minY))
			switch placement.anchor {
				case .NE, .SE: label.view.textAlignment = .left
				case .NW, .SW: label.view.textAlignment = .right
				case .Center: label.view.textAlignment = .center
			}
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
	
	func bindMarkers(_ newMarkers: [LabelMarker], to labels: [Label]) {
		var markers = newMarkers
		for label in labels {
			guard let marker = markers.popLast() else { return }
			bindLabel(label, to: marker)
		}
	}
	
	func bindLabel(_ label: Label, to marker: LabelMarker) {
		label.ownerHash = marker.ownerHash
		label.view.isHidden = false
		
		let textColor: UIColor
		let strokeColor: UIColor
		let strokeWidth: CGFloat
		
		switch marker.kind {
		case .Region:
			textColor = .darkGray	// $ Stylesheet
			strokeColor = .white
			strokeWidth = -2.0
		default:
			textColor = .lightGray // $ Stylesheet
			strokeColor = .darkGray
			strokeWidth = -4.0
		}
		
		let labelLineSpacing: CGFloat = 2.0
		let font = marker.font
		let paragraphStyle = NSMutableParagraphStyle()
		let lineHeight = font.pointSize - font.ascender + font.capHeight
		let offset = font.capHeight - font.ascender
		paragraphStyle.minimumLineHeight = lineHeight
		paragraphStyle.maximumLineHeight = lineHeight + labelLineSpacing
		
		let attribs: [NSAttributedString.Key: Any] = [
			.font: marker.font,
			.strokeColor: strokeColor,
			.foregroundColor: textColor,
			.strokeWidth: strokeWidth,
			.paragraphStyle: paragraphStyle,
			.baselineOffset: offset
		]
		
		let text = marker.displayText as String
		label.view.attributedText = NSAttributedString(string: text, attributes: attribs)
		
		labelAges[marker.ownerHash] = Date().timeIntervalSince1970
	}
	
	func unbindLabel(_ label: Label) {
		labelAges.removeValue(forKey: label.ownerHash)
		label.ownerHash = 0
		label.view.isHidden = true
	}
}
