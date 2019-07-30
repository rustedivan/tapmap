//
//  nullrenderer.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-02-12.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class ArrayedRenderPrimitive {
	init() {}
	init(vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

class IndexedRenderPrimitive {
	init() {}
	init(vertices: [Vertex], indices: [UInt32], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

class OutlineRenderPrimitive {
	init() {}
	init(vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
	}
}

extension GeoRegion : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> ArrayedRenderPrimitive {
		return ArrayedRenderPrimitive()
	}
	
	func placesRenderPlane() -> IndexedRenderPrimitive {
		return IndexedRenderPrimitive()
	}
}

extension GeoCountry : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> ArrayedRenderPrimitive {
		return ArrayedRenderPrimitive()
	}
	
	func placesRenderPlane() -> IndexedRenderPrimitive {
		return IndexedRenderPrimitive()
	}
}

extension GeoContinent : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> ArrayedRenderPrimitive {
		return ArrayedRenderPrimitive()
	}
	
	func placesRenderPlane() -> IndexedRenderPrimitive {
		return IndexedRenderPrimitive()
	}
}
