//
//  OperationTesselateBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift
import simd

class OperationTesselateBorders : Operation {
	let world : GeoWorld
	let report : ProgressReport
	var error : Error?
	
	init(_ worldToTesselate: GeoWorld, reporter: @escaping ProgressReport) {
		world = worldToTesselate
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
	}
}

func tesselate(range: VertexRange, ofVertices vertices: [Vertex]) -> [Int] {
	guard let tess = TessC() else {
		print("Could not init TessC")
		return []
	}
	
	let vs = vertices[Int(range.start) ..< Int(range.start + range.count)]
	
	let contour = vs.map {
		CVector3(x: $0.v.0, y: $0.v.1, z: 0.0)
	}
	
	tess.addContour(contour)
	do {
		let t = try tess.tessellate(windingRule: .evenOdd,
		                    elementType: ElementType.polygons,
		                    polySize: 3,
												vertexSize: .vertex2)
		print(t)
		return t.indices
	} catch (let e) {
		print(e)
		return []
	}
}
