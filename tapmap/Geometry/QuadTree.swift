//
//  QuadTree.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

indirect enum QuadNode<T: Hashable & Codable>: Codable {
	typealias Element = T
	enum CodingKeys: CodingKey {
		case bounds
		case values
		case topLeft, topRight, bottomLeft, bottomRight
	}
	case Node(bounds: Aabb, values: Set<T>, tl: QuadNode, tr: QuadNode, bl: QuadNode, br: QuadNode)
	case Empty(bounds: Aabb)
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let bounds = try container.decode(Aabb.self, forKey: .bounds)
		if container.allKeys.contains(CodingKeys.values) {
			let values = try! container.decode(Set<T>.self, forKey: .values)
			let tl = try! container.decode(QuadNode<T>.self, forKey: .topLeft)
			let tr = try! container.decode(QuadNode<T>.self, forKey: .topRight)
			let bl = try! container.decode(QuadNode<T>.self, forKey: .bottomLeft)
			let br = try! container.decode(QuadNode<T>.self, forKey: .bottomRight)
			self = .Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
		} else {
			self = .Empty(bounds: bounds)
		}
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case let .Node(bounds, values, tl, tr, bl, br):
			try container.encode(bounds, forKey: .bounds)
			try container.encode(values, forKey: .values)
			try container.encode(tl, forKey: .topLeft)
			try container.encode(tr, forKey: .topRight)
			try container.encode(bl, forKey: .bottomLeft)
			try container.encode(br, forKey: .bottomRight)
		case let .Empty(bounds):
			try container.encode(bounds, forKey: .bounds)
		}
	}
	
	var bounds: Aabb { get {
		switch self {
			case let .Node(bounds, _, _, _, _, _), let .Empty(bounds):
			return bounds
		}
	}}
	
	func contains(region a: Aabb) -> Bool {
		let b = bounds
		return (a.minX >= b.minX && a.minY >= b.minY &&
						a.maxX <  b.maxX && a.maxY <  b.maxY)
	}
	
	func intersects(search a: Aabb) -> Bool {
		let b = bounds
		return !( a.minX >= b.maxX ||
							a.maxX <= b.minX ||
							a.minY >= b.maxY ||
							a.maxY <= b.minY)
	}
	
	func subnodes() -> (tl: QuadNode, tr: QuadNode, bl: QuadNode, br: QuadNode) {
		let b = bounds
		let tlOut = QuadNode.Empty(bounds: Aabb(loX: b.minX, loY: b.midpoint.y, hiX: b.midpoint.x, hiY: b.maxY))
		let trOut = QuadNode.Empty(bounds: Aabb(loX: b.midpoint.x, loY: b.midpoint.y, hiX: b.maxX, hiY: b.maxY))
		let blOut = QuadNode.Empty(bounds: Aabb(loX: b.minX, loY: b.minY, hiX: b.midpoint.x, hiY: b.midpoint.y))
		let brOut = QuadNode.Empty(bounds: Aabb(loX: b.midpoint.x, loY: b.minY, hiX: b.maxX, hiY: b.midpoint.y))
		return (tlOut, trOut, blOut, brOut)
	}
}

func splitNode<T>(_ node: QuadNode<T>) -> QuadNode<T> {
	let subCells = node.subnodes()
	return QuadNode.Node(bounds: node.bounds, values: [],
												tl: subCells.tl,
												tr: subCells.tr,
												bl: subCells.bl,
												br: subCells.br)
}

struct QuadTree<T: Hashable & Codable>: Codable {
	var root: QuadNode<T>
	let maxDepth: Int
	
	init(minX: Vertex.Precision, minY: Vertex.Precision, maxX: Vertex.Precision, maxY: Vertex.Precision, maxDepth: Int) {
		let emptyRoot = QuadNode<T>.Empty(bounds: Aabb(loX: minX, loY: minY, hiX: maxX, hiY: maxY))
		self.root = splitNode(emptyRoot)
		self.maxDepth = maxDepth
	}
	
	mutating func insert(value: T, region: Aabb) {
		guard root.contains(region: region) else {
			print("Value \(value) lies outside quadtree bounds: \(region)")
			return
		}
		(root, _) = quadInsert(value, region: region, into: root, depth: 1, maxDepth: maxDepth)
	}
	
	mutating func remove(hashValue: Int) {
		root = quadRemove(hashValue, from: root)
	}
	
	func query(search: Aabb) -> Set<T> {
		return quadQuery(search: search, in: root)
	}
}

func quadInsert<T:Hashable>(_ value: T, region: Aabb, into node: QuadNode<T>, depth: Int, maxDepth: Int) -> (QuadNode<T>, Int) {
	switch (node) {
	case .Empty:
		// Convert leaf to inner node and keep inserting
		let newNode = splitNode(node)
		return quadInsert(value, region: region, into: newNode, depth: depth, maxDepth: maxDepth)
	case .Node(let bounds, var values, var tl, var tr, var bl, var br):
		let nextDepth = depth + 1
		// If there's room below:
		if (nextDepth <= maxDepth) {
			func insertValueInto(_ target: QuadNode<T>) -> (QuadNode<T>, Int) {
				quadInsert(value, region: region, into: target, depth: nextDepth, maxDepth: maxDepth)
			}
			let newDepth: Int
			// Try to fit into subcells below...
			if      (tl.contains(region: region)) { (tl, newDepth) = insertValueInto(tl) }
			else if (tr.contains(region: region)) { (tr, newDepth) = insertValueInto(tr) }
			else if (bl.contains(region: region)) { (bl, newDepth) = insertValueInto(bl) }
			else if (br.contains(region: region)) { (br, newDepth) = insertValueInto(br) }
			else {
				// ...or keep the value here
				newDepth = depth
				values.insert(value)
			}
			let node = QuadNode.Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
			return (node, newDepth)
		} else {
			// If at max depth, keep the value here
			values.insert(value)
			let node = QuadNode.Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
			return (node, depth)
		}
	}
}

func quadRemove<T:Hashable>(_ hashValue: Int, from node: QuadNode<T>) -> QuadNode<T> {
	var result: QuadNode<T>
	switch (node) {
	case .Empty:
		// No effect
		return node
	case .Node(let bounds, var values, var tl, var tr, var bl, var br):
		if let targetIndex = values.firstIndex(where: { $0.hashValue == hashValue }) {
			// Value found, update the node
			values.remove(at: targetIndex)
			result = .Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
		} else {
			// Look in subcells and update with result
			tl = quadRemove(hashValue, from: tl)
			tr = quadRemove(hashValue, from: tr)
			bl = quadRemove(hashValue, from: bl)
			br = quadRemove(hashValue, from: br)
			result = .Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
		}
		if case (.Empty, .Empty, .Empty, .Empty) = (tl, tr, bl, br), values.isEmpty {
			// If the subtree is now completely empty, close this node too
			result = .Empty(bounds: bounds)
		}
		return result
	}
}

func quadQuery<T:Hashable>(search: Aabb, in node: QuadNode<T>) -> Set<T> {
	switch (node) {
	case .Empty:
		return Set<T>()
	case let .Node(_, values, tl, tr, bl, br):
		if node.intersects(search: search) {
			var subtreeValues = Set<T>(values)
			subtreeValues.formUnion(quadQuery(search: search, in: tl))
			subtreeValues.formUnion(quadQuery(search: search, in: tr))
			subtreeValues.formUnion(quadQuery(search: search, in: bl))
			subtreeValues.formUnion(quadQuery(search: search, in: br))
			return subtreeValues
		} else {
			return Set<T>()
		}
	}
}
