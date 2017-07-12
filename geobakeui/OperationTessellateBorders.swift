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

class OperationTessellateBorders : Operation {
	var world : GeoWorld
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(_ worldToTessellate: GeoWorld, reporter: @escaping ProgressReport, errorReporter: @escaping ErrorReport) {
		world = worldToTessellate
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var totalTris = 0
		
		let tessellatedContinents = world.continents.map { continent -> GeoContinent in
			let tessellatedRegions = continent.regions.map { region -> GeoRegion in
				if let tessellation = tessellate(region: region, continentVertices: continent.borderVertices) {
					totalTris += tessellation.vertices.count
					report(0.3, "Tesselated \(region.name) (total \(totalTris) triangles", false)
					return GeoRegion.addTessellation(region: region, tessellation: tessellation)
				} else {
					reportError(region.name, "Tesselation failed")
					return region
				}
			}
			return GeoContinent(name: continent.name,
			                    borderVertices: continent.borderVertices,
			                    regions: tessellatedRegions)
		}
		world = GeoWorld(continents: tessellatedContinents)
		print("Tessellated \(totalTris) triangles")
	}
}

func tessellate(region: GeoRegion, continentVertices vertices: [Vertex]) -> GeoTessellation? {
	guard let tess = TessC() else {
		print("Could not init TessC")
		return nil
	}
	
	for feature in region.features {
		let contour : [CVector3]
		do {
			let start : Int = Int(feature.vertexRange.start)
			let end : Int = start + Int(feature.vertexRange.count)
			let vs = vertices[start ..< end]
			contour = vs.map {
				CVector3(x: $0.v.0, y: $0.v.1, z: 0.0)
			}
		}
		tess.addContour(contour)
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


