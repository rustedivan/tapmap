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
	let vertices: [Vertex] = []
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

extension GeoRegion {
	func poiRenderPlanes() -> [PoiPlane] {
		return []
	}
}

extension GeoCountry {
	func poiRenderPlanes() -> [PoiPlane] {
		return []
	}
}

extension GeoContinent {
	func poiRenderPlanes() -> [PoiPlane] {
		return []
	}
}

struct PoiPlane {
	
}

class GeometryStreamer {
	let actualLodLevel = 0
	static var shared: GeometryStreamer { get {
		return GeometryStreamer()
	}}
	func tessellation(for: Int, atLod: Int) -> ArrayedRenderPrimitive? {
		return nil
	}
}
