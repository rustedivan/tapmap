//
//  OperationTesselateBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift

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
	
	func tesselate(range: VertexRange, ofVertices: [Vertex]) {
		guard let tess = TessC() else {
			print("Could not init TessC")
			return
		}
	}
	
	
}

