//
//  nullrenderer.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-02-12.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class ArrayedRenderPrimitive {
	let ownerHash = 17
	init() {}
	init(vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

class IndexedRenderPrimitive {
	let ownerHash = 17
	init() {}
	init(vertices: [Vertex], indices: [UInt32], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

class OutlineRenderPrimitive {
	let ownerHash = 17
	init() {}
	init(vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

extension GeoRegion : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> ArrayedRenderPrimitive {
		return ArrayedRenderPrimitive()
	}
	
	func poiRenderPlanes() -> [PoiPlane] {
		return []
	}
}

extension GeoCountry : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> ArrayedRenderPrimitive {
		return ArrayedRenderPrimitive()
	}
	
	func poiRenderPlanes() -> [PoiPlane] {
		return []
	}
}

extension GeoContinent : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> ArrayedRenderPrimitive {
		return ArrayedRenderPrimitive()
	}
	
	func poiRenderPlanes() -> [PoiPlane] {
		return []
	}
}

struct PoiPlane {
	
}
