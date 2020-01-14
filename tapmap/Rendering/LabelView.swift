//
//  LabelView.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-21.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import UIKit

struct LabelMarker {
	let name: String
	let ownerHash: Int
	let worldPos: Vertex
	let kind: GeoPlace.Kind
	
	init(for poi: GeoPlace) {
		name = poi.name
		ownerHash = poi.hashValue
		worldPos = poi.location
		kind = poi.kind
	}
}

class LabelView: UIView {
	@IBOutlet var oneLabel: UILabel!
	var poiPrimitives: [Int: LabelMarker] = [:]
	
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
	
	func renderLabels(for renderedPoiHashes: Set<Int>, inArea focus: Aabb) {
		let availablePois = poiPrimitives.filter { renderedPoiHashes.contains($0.value.ownerHash) }
		_ = availablePois.filter { boxContains(focus, $0.value.worldPos) }
	}
	
	func updateLabels(_ labels: [(name: String, screenPos: CGPoint)]) {
		oneLabel.text = labels.first?.name
		oneLabel.frame.origin = labels.first?.screenPos ?? .zero
	}
}
