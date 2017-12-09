//
//  ToolGeometry.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-11-30.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

struct GeoPolygonRing {
    let vertices: [Vertex]
}

struct GeoPolygon {
    let exteriorRing: GeoPolygonRing
    let interiorRings: [GeoPolygonRing]
    
    func totalVertexCount() -> Int {
        return exteriorRing.vertices.count +
            interiorRings.reduce(0) { $0 + $1.vertices.count }
    }
}

struct GeoFeature {
	let name: String
    let regionName: String
    let polygons: [GeoPolygon]
    
	func totalVertexCount() -> Int {
        return polygons.reduce(0) { $0 + $1.totalVertexCount() }
	}
}

struct GeoFeatureCollection {
    let name: String
    let features: [GeoFeature]
    
    func totalVertexCount() -> Int {
        return features.reduce(0) { $0 + $1.totalVertexCount() }
    }
}
