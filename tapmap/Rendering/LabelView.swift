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
	static let s_maxLabels = 20
	var poiMarkers: [Int : LabelMarker] = [:]
	var poiLabels: [Label] = []
	var layoutEngine: LabelLayoutEngine!
	
	override func awakeFromNib() {
		let s = UIScreen.main.bounds
		layoutEngine = LabelLayoutEngine(maxLabels: LabelView.s_maxLabels,
																		 space: Aabb(loX: Float(s.minX), loY: Float(s.minY),
																								 hiX: Float(s.maxX), hiY: Float(s.maxY)),
																		 measure: measureLabel)
		for _ in 0 ..< LabelView.s_maxLabels {
			let newLabel = Label()
			poiLabels.append(newLabel)
			addSubview(newLabel.view)
		}
	}
	
	func initPoiMarkers(withVisibleContinents continents: GeoContinentMap,
											countries: GeoCountryMap,
											provinces: GeoProvinceMap) {
		// Collect a flat list of all POIs and their hash keys
		let continentPois = continents.flatMap { $0.value.places }
		let countryPois = countries.flatMap { $0.value.places }
		let provincePois = provinces.flatMap { $0.value.places }
		let allPois = continentPois + countryPois + provincePois
		let allPoiPrimitives = allPois.map { ($0.hashValue, LabelMarker(for: $0)) }
		
		self.poiMarkers = Dictionary(uniqueKeysWithValues: allPoiPrimitives)
	}
	
	func updatePoiMarkers<T:GeoNode & GeoPlaceContainer>(for node: T, with subRegions: Set<T.SubType>)
		where T.SubType: GeoPlaceContainer  {
		for poi in node.places {
			poiMarkers.removeValue(forKey: poi.hashValue)
		}
		
		let subRegionPois = subRegions.flatMap { $0.places }
		let hashedPrimitives = subRegionPois.map {
			($0.hashValue, LabelMarker(for: $0))
		}
		poiMarkers.merge(hashedPrimitives, uniquingKeysWith: { (l, r) in print("Replacing"); return l })
	}
	
	func updateLabels(for activePoiHashes: Set<Int>, inArea focus: Aabb, atZoom zoom: Float, projection project: (Vertex) -> CGPoint) {
		let activeMarkers = poiMarkers.filter { activePoiHashes.contains($0.value.ownerHash) }
		let visibleMarkers = activeMarkers.filter { zoomFilter($0.value, zoom) && boxContains(focus, $0.value.worldPos) }
		let visibleMarkerHashes = Set<Int>(visibleMarkers.keys)
		
		// $ Widen the poi marker viewbox by ~100px
		// $ Speed up the projection func
		
		// Free up labels whose markers disappeared
		var freeLabels = poiLabels.filter { $0.ownerHash == 0 || visibleMarkerHashes.contains($0.ownerHash) == false}
		freeLabels
			.filter { $0.ownerHash != 0 }
			.forEach {
				layoutEngine.removeFromLayout($0.ownerHash)
				unbindLabel($0)
			}
		
		// Find new/unbound markers
		let labelBindings = Set<Int>(poiLabels.map { $0.ownerHash })
		let unboundMarkers = visibleMarkers.filter { !labelBindings.contains($0.key) }
		
		// Run layout engine over all markers
		let (layout, removed) = layoutEngine.layoutLabels(markers: visibleMarkers,
																											projection: project)
		let removedLabels = poiLabels.filter { removed.contains($0.ownerHash) }
		removedLabels.forEach {
//			print("\($0.view.text!) (\($0.ownerHash)) got knocked out of the layout")
			unbindLabel($0)
		}
		freeLabels.append(contentsOf: removedLabels)
		
		// Bind newly laid-out markers to free labels
		var newLayoutEntries = unboundMarkers.filter { layout.keys.contains($0.key) }
		for label in freeLabels {
			guard let marker = newLayoutEntries.popFirst() else { break }
			bindLabel(label, to: marker.value)
		}
		
		// Move UILabels into place
		let usedLabels = poiLabels.filter { $0.ownerHash != 0 }
		moveLabels(usedLabels, to: layout)
	}
	
	func moveLabels(_ labels: [Label], to layout: LabelLayout) {
		// Move all labels into place
		for label in labels {
			guard let placement = layout[label.ownerHash] else {
//				print("Label for \(label.view.text!) knocked out from layout.")
				continue
			}

			let labelRect = placement.aabb
			label.view.frame = CGRect(x: CGFloat(labelRect.minX),
																y: CGFloat(labelRect.minY),
																width: CGFloat(labelRect.width),
																height: CGFloat(labelRect.height))
			switch placement.anchor {
				case .NE, .SE: label.view.textAlignment = .left
				case .NW, .SW: label.view.textAlignment = .right
				case .Center: label.view.textAlignment = .center
			}
		}
	}
	
	func zoomFilter(_ marker: LabelMarker, _ zoom: Float) -> Bool {
		// Region markers should go away after we've zoomed "past" them
		switch(marker.kind, marker.rank) {
			case (.Region, 0): return zoom < 5.0
			case (.Region, 1): return zoom < 10.0
			default: return true
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
		label.view.backgroundColor = UIColor(red: 0.3, green: 0.0, blue: 0.0, alpha: 0.3)
	}
	
	func unbindLabel(_ label: Label) {
		guard label.ownerHash != 0 else { return }
		label.ownerHash = 0
		label.view.isHidden = true
	}
}

func measureLabel(marker: LabelMarker) -> (w: Float, h: Float) {
	let font = marker.font
	let size = marker.displayText.boundingRect(with: CGSize(width: 120.0, height: 120.0),
																										options: .usesLineFragmentOrigin,
																										attributes: [.font: font],
																										context: nil)
																										.size
	let wh = (w: Float(ceil(size.width)), h: Float(ceil(size.height)))
	return wh
}
