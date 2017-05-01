//
//  GeoRegion.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

typealias GeoColor = (r: Float, g: Float, b: Float)

struct GeoColors {
	
	static func randomColor() -> GeoColor {
		let r = Float(arc4random_uniform(100)) / 100.0
		let g = Float(arc4random_uniform(100)) / 100.0
		let b = Float(arc4random_uniform(100)) / 100.0
		return GeoColor(r: r, g: g, b: b)
	}
}

struct Vertex {
	let v: (Float, Float)
}

struct Triangle {
	let i: (Int, Int, Int)
}

typealias VertexRange = (start: UInt32, count: UInt32)

struct GeoFeature {
	let vertexRange: VertexRange
}

struct GeoRegion {
	let name: String
	let color: GeoColor
	let features: [GeoFeature]
}

struct GeoContinent {
	let name: String
	let vertices: [Vertex]
	let regions: [GeoRegion]
}

struct GeoWorld {
	let continents: [GeoContinent]
}

// TODO: replace GeoFeature's vertexRange with this index list
struct GeoTesselation {
	let triangles: [Triangle]
}
