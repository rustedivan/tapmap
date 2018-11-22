//
//  AppUtils.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-06-27.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

extension Vertex : Codable {
	func encode(to encoder: Encoder) throws {
		var container = encoder.unkeyedContainer()
		try container.encode(contentsOf: [x, y])
	}

	init(from decoder: Decoder) throws {
		var container = try decoder.unkeyedContainer()
		x = try container.decode(Float.self)
		y = try container.decode(Float.self)
	}
}

extension Triangle : Codable {
	func encode(to encoder: Encoder) throws {
		var container = encoder.unkeyedContainer()
		try container.encode(contentsOf: [i.0, i.1, i.2])
	}
	
	init(from decoder: Decoder) throws {
		var container = try decoder.unkeyedContainer()
		let i0 = try container.decode(Int.self)
		let i1 = try container.decode(Int.self)
		let i2 = try container.decode(Int.self)
		i = (i0, i1, i2)
	}
}
