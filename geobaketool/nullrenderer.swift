//
//  nullrenderer.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-02-12.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class RenderPrimitive {
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
