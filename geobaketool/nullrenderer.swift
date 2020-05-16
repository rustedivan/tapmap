//
//  nullrenderer.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-02-12.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class IndexedRenderPrimitive {
	let ownerHash = 17
	init() {}
	init(vertices: [Vertex], indices: [UInt16], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

class GeometryStreamer {
	let actualLodLevel = 0
	static var shared: GeometryStreamer { get {
		return GeometryStreamer()
	}}
	func tessellation(for: Int, atLod: Int) -> GeoTessellation? {
		return nil
	}
}
