//
//  AppTypes.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-09.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

struct Vertex : Equatable {
	typealias Precision = Float
	var p: Vertex { return self }
	
	let x: Precision
	let y: Precision
	
	init(_ _x: Precision, _ _y: Precision) { x = _x; y = _y; }
	
	var quantized : (Int64, Int64) {
		let quant: Precision = 1e-6
		return (Int64(floor(x / quant)), Int64(floor(y / quant)))
	}
	
	static func ==(lhs: Vertex, rhs: Vertex) -> Bool {
		return lhs.quantized == rhs.quantized
	}
	
	static func +(lhs: Vertex, rhs: Vertex) -> Vertex {
		return Vertex(lhs.x + rhs.x, lhs.y + rhs.y)
	}
}

struct ScaleVertex {
	let x: Float
	let y: Float
	let normalX: Float
	let normalY: Float
	
	init(_ _x: Float, _ _y: Float, normalX _nx: Float, normalY _ny: Float) {
		x = _x; y = _y;
		normalX = _nx; normalY = _ny;
	}
}

struct VertexRing : Codable {
	var vertices: [Vertex]
}
