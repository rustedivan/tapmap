//
//  nullrenderer.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-02-12.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class RenderPrimitive {
	init() {
		
	}
	init(vertices: [Vertex], indices: [UInt32], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
		
	}
	init(vertices: [Vertex], color c: (r: Float, g: Float, b: Float, a: Float), ownerHash hash: Int, debugName: String) {
		
	}
}

extension GeoRegion : Renderable {
	func renderPrimitive() -> RenderPrimitive {
		return RenderPrimitive()
	}
	
	func placesRenderPlane() -> RenderPrimitive {
		return RenderPrimitive()
	}
}

extension GeoCountry : Renderable {
	func renderPrimitive() -> RenderPrimitive {
		return RenderPrimitive()
	}
	
	func placesRenderPlane() -> RenderPrimitive {
		return RenderPrimitive()
	}
}

extension GeoContinent : Renderable {
	func renderPrimitive() -> RenderPrimitive {
		return RenderPrimitive()
	}
	
	func placesRenderPlane() -> RenderPrimitive {
		return RenderPrimitive()
	}
}
