//
//  ToolGeometry.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-11-30.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

struct GeoFeature {
	let vertices: [Vertex]
}

struct GeoMultiFeature {
	let name: String
	let subFeatures: [GeoFeature]
	let subMultiFeatures: [GeoMultiFeature]
	
	func totalVertexCount() -> Int {
		return subFeatures.reduce(0) { $0 + $1.vertices.count } +
					 subMultiFeatures.reduce(0) { $0 + $1.totalVertexCount() }
	}
}
