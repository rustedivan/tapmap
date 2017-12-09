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
	var continents : [GeoMultiFeature]
	let report : ProgressReport
	let reportError : ErrorReport
	var tessellatedContinents : [GeoContinent]
	var error : Error?
	
	init(_ continentsToTessellate: [GeoMultiFeature], reporter: @escaping ProgressReport, errorReporter: @escaping ErrorReport) {
		continents = continentsToTessellate
		report = reporter
		reportError = errorReporter
		tessellatedContinents = []
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		var totalTris = 0
		
		tessellatedContinents = continents.map { continent -> GeoContinent in
			// Tessellate countries
			let tessellatedRegions = continent.subMultiFeatures.map { region -> GeoRegion? in
				if let tessellation = tessellate(region: region) {
					totalTris += tessellation.vertices.count
					report(0.3, "Tesselated \(region.name) (total \(totalTris) triangles", false)
					return GeoRegion(name: region.name, color: GeoColors.randomColor(), geometry: tessellation)
				} else {
					reportError(region.name, "Tesselation failed")
					return nil
				}
			}
			return GeoContinent(name: continent.name,
													regions: tessellatedRegions.flatMap { $0 })
		}
		
		print("Tessellated \(totalTris) triangles")
	}
}

func tessellate(region: GeoMultiFeature) -> GeoTessellation? {
	guard let tess = TessC() else {
		print("Could not init TessC")
		return nil
	}

	let features = gatherFlatFeatures(from: region)

	for feature in features {
		let contour : [CVector3]
		do {
			contour = feature.vertices.map {
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

func gatherFlatFeatures(from f: GeoMultiFeature) -> [GeoFeature] {
	return	f.subFeatures +
					f.subMultiFeatures.reduce([]) { $0 + gatherFlatFeatures(from: $1) }
}