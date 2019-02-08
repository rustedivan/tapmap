//
//  AppTypes.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-09.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

struct Vertex {
	typealias Precision = Float
	var p: Vertex { return self }
	
	let x: Precision
	let y: Precision
	init(_ _x: Precision, _ _y: Precision) { x = _x; y = _y }
	init(_ _x: Double, _ _y: Double) { x = Precision(_x); y = Precision(_y) }
}
