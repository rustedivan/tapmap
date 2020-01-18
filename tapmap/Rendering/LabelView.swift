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
		return lhs.rank < rhs.rank
	}
}

class LabelView: UIView {
	static let s_maxLabels = 10
	var poiPrimitives: [Int: LabelMarker] = [:]
	var poiLabels: [UILabel] = []
	
	override func awakeFromNib() {
		for _ in 0 ..< LabelView.s_maxLabels {
			let newLabel = UILabel()
			newLabel.tag = 0
			newLabel.isHidden = true
			newLabel.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 30.0)
			poiLabels.append(newLabel)
			addSubview(newLabel)
		}
	}
	
	func buildPoiPrimitives(withVisibleContinents continents: [Int: GeoContinent],
													countries: [Int: GeoCountry],
													regions: [Int: GeoRegion]) {
		
		// Collect a flat list of all POIs and their hash keys
		let continentPois = continents.flatMap { $0.value.places }
		let countryPois = countries.flatMap { $0.value.places }
		let regionPois = regions.flatMap { $0.value.places }
		let allPois = continentPois + countryPois + regionPois
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
	
	func updateLabels(for activePoiHashes: Set<Int>, inArea focus: Aabb) {
		// Pick out the top-ten markers for display
		let activeMarkers = poiPrimitives.values.filter { activePoiHashes.contains($0.ownerHash) }
		let visibleMarkers = activeMarkers.filter { boxContains(focus, $0.worldPos) }
		let prioritizedMarkers = visibleMarkers.sorted(by: <)
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
			
			bindLabel(freeLabel, to: marker.ownerHash)
		}
	}
	
	func renderLabels(projection project: (Vertex) -> CGPoint) {
		for label in poiLabels {
			guard let marker = poiPrimitives.values.first(where: { $0.ownerHash == label.tag }) else {
				continue
			}
			label.text = marker.name
			let screenPos = project(marker.worldPos)
			label.frame.origin = screenPos
		}
	}
	
	func bindLabel(_ label: UILabel, to hash: Int) {
		label.tag = hash
		label.isHidden = false
	}
	
	func unbindLabel(_ label: UILabel) {
		label.tag = 0
		label.isHidden = true
	}
}
