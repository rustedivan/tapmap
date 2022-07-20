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
	var ownerHash: RegionHash = 0
	var isHiding = false
	
	init() {
		view = UILabel()
		view.isHidden = true
		view.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 30.0)
		view.preferredMaxLayoutWidth = 100.0
		view.lineBreakMode = .byWordWrapping
		view.numberOfLines = 2
		view.allowsDefaultTighteningForTruncation = true
	}
	
	var isBound: Bool {
		return ownerHash != 0
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
	
	func updateLabels(for candidatePoiHashes: Set<Int>, inArea focus: Aabb, atZoom zoom: Float, projection project: (Vertex) -> CGPoint) {
		let candidateMarkers = poiMarkers.filter { candidatePoiHashes.contains($0.value.ownerHash) }
		let clipHiddenMarkerHashes = candidateMarkers.filter { !boxContains(focus, $0.value.worldPos) }.keys
		let zoomHiddenMarkerHashes = candidateMarkers.filter { !zoomFilter($0.value, zoom) }.keys
		let visibleMarkers = candidateMarkers.filter { !clipHiddenMarkerHashes.contains($0.key) && !zoomHiddenMarkerHashes.contains($0.key) }
		
		// Run layout engine over all markers
		let (layout, removed) = layoutEngine.layoutLabels(markers: visibleMarkers,
																											projection: project)

		// $ Widen the poi marker viewbox by ~100px
		// $ Speed up the projection func
		
		let removedLabels = poiLabels.filter { zoomHiddenMarkerHashes.contains($0.ownerHash) || removed.contains($0.ownerHash) }
		let clippedLabels = poiLabels.filter { clipHiddenMarkerHashes.contains($0.ownerHash) }
		let fadedLabels = poiLabels.filter { $0.view.isHidden && $0.isBound }
		
		removedLabels.forEach { removedLabel in
			if !removedLabel.isHiding {
				hideLabel(removedLabel)
			}
		}
		
		clippedLabels.forEach { clippedLabel in
			clippedLabel.view.isHidden = true
			unbindLabel(clippedLabel)
		}
		
		fadedLabels.forEach { fadedLabel in
			unbindLabel(fadedLabel)
		}

		// Find new/unbound markers
		let labelBindings = Set<Int>(poiLabels.map { $0.ownerHash })
		let unboundMarkers = visibleMarkers.filter { !labelBindings.contains($0.key) }
		
		// Bind newly laid-out markers to free labels
		var newLayoutEntries = unboundMarkers.filter { layout.keys.contains($0.key) }
		let freeLabels = poiLabels.filter { !$0.isBound }
		for label in freeLabels {
			guard let marker = newLayoutEntries.popFirst() else { break }
			bindLabel(label, to: marker.value)
		}
		
		// Move UILabels into place
		let usedLabels = poiLabels.filter { $0.isBound }
		moveLabels(usedLabels, to: layout)
	}
	
	func moveLabels(_ labels: [Label], to layout: LabelLayout) {
		// Move all labels into place
		for label in labels {
			guard let placement = layout[label.ownerHash] else {
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
		UIView.animate(withDuration: 0.2) {
			label.view.alpha = 1.0
		}
		
		let textColor: UIColor
		let strokeColor: UIColor
		let strokeWidth: CGFloat
		
		switch marker.kind {
		case .Region:
			textColor = .darkGray
			strokeColor = .white
			strokeWidth = -2.0
		default:
			textColor = .lightGray
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
	}
	
	func unbindLabel(_ label: Label) {
		guard label.isBound else { return }
		label.ownerHash = 0
		label.isHiding = false
	}
	
	func hideLabel(_ label: Label) {
		guard label.isBound else { return }
		label.isHiding = true
		UIView.animate(withDuration: 0.2) {
			label.view.alpha = 0.0
		} completion: { done in
			label.view.isHidden = true
		}
	}
}

func measureLabel(marker: LabelMarker) -> (w: Float, h: Float) {
	let font = marker.font
	let size = marker.displayText.boundingRect(with: CGSize(width: 140.0, height: 120.0),
																										options: .usesLineFragmentOrigin,
																										attributes: [.font: font],
																										context: nil)
																										.size
	let wh = (w: Float(ceil(size.width)), h: Float(ceil(size.height)))
	return wh
}

extension LabelMarker {
	var font: UIFont {
		switch kind {
			case .Region:
				switch rank {
					case 0: return Stylesheet.shared.largeRegionFont
					case 1: return Stylesheet.shared.mediumRegionFont
					default: return Stylesheet.shared.defaultRegionFont
				}
			case .Capital: return Stylesheet.shared.capitalFont
			case .City: return Stylesheet.shared.cityFont
			case .Town: return Stylesheet.shared.townFont
		}
	}
}
