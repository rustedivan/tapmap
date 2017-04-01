//
//  GeoRegion.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import UIKit.UIColor

struct Vertex {
	let v: (Float, Float)
}

typealias VertexRange = (start: UInt32, count: UInt32)

struct GeoFeature {
	let vertexRange: VertexRange
}

struct GeoRegion {
	let name: String
	let color: UIColor
	let parts: [GeoFeature]
}

struct GeoContinent {
	let name: String
	let vertices: [Vertex]
	let regions: [GeoRegion]
}

struct GeoWorld {
	let continents: [GeoContinent]
}
