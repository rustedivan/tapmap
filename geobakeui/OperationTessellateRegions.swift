//
//  OperationTessellateBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift
import simd

class OperationTessellateRegions : Operation {
	var world : GeoFeatureCollection
	let report : ProgressReport
	let reportError : ErrorReport
	var tessellatedRegions : [GeoRegion]
	var error : Error?
	
	init(_ featuresToTessellate: GeoFeatureCollection, reporter: @escaping ProgressReport, errorReporter: @escaping ErrorReport) {
        world = featuresToTessellate
		report = reporter
		reportError = errorReporter
		tessellatedRegions = []
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var totalTris = 0
		
		tessellatedRegions = world.features.compactMap { feature -> GeoRegion? in
				if let tessellation = tessellate(feature) {
						totalTris += tessellation.vertices.count
						report(0.3, "Tesselated \(feature.name) (total \(totalTris) triangles", false)
						return GeoRegion(name: feature.name, geometry: tessellation)
				} else {
						reportError(feature.name, "Tesselation failed")
						return nil
				}
		}
		
		print("Tessellated \(totalTris) triangles")
	}
}

func tessellate(_ feature: GeoFeature) -> GeoTessellation? {
    guard let tess = TessC() else {
        print("Could not init TessC")
        return nil
    }

    for polygon in feature.polygons {
        let exterior = polygon.exteriorRing.contour
        tess.addContour(exterior)
        let interiorContours = polygon.interiorRings.map{ $0.contour }
        for interior in interiorContours {
            tess.addContour(interior)
        }
    }

    do {
        let t = try tess.tessellate(windingRule: .evenOdd,
                            elementType: ElementType.polygons,
                            polySize: 3,
                                                vertexSize: .vertex2)
        let regionVertices = t.vertices.map {
            Vertex(v: ($0.x, $0.y))
        }
        let indices = t.indices.map { UInt32($0) }
        let aabb = regionVertices.reduce(Aabb()) { aabb, v in
            let out = Aabb(loX: min(v.v.0, aabb.minX),
                           loY: min(v.v.1, aabb.minY),
                           hiX: max(v.v.0, aabb.maxX),
                           hiY: max(v.v.1, aabb.maxY))
            return out
        }

        return GeoTessellation(vertices: regionVertices, indices: indices, aabb: aabb)
    } catch {
        return nil
    }
}

fileprivate extension GeoPolygonRing {
    var contour : [CVector3] {
        return vertices.map { CVector3(x: $0.v.0, y: $0.v.1, z: 0.0) }
    }
}
