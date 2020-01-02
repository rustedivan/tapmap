//
//  QuadTree.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

indirect enum QuadNode {
	case Node(bounds: Aabb, values: Set<Int>, tl: QuadNode, tr: QuadNode, bl: QuadNode, br: QuadNode)
	case Empty(bounds: Aabb)
	
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
	
	func subcells() -> (tl: Aabb, tr: Aabb, bl: Aabb, br: Aabb) {
		let b = bounds
		let tlOut = Aabb(loX: b.minX, loY: b.midpoint.y, hiX: b.midpoint.x, hiY: b.maxY)
		let trOut = Aabb(loX: b.midpoint.x, loY: b.midpoint.y, hiX: b.maxX, hiY: b.maxY)
		let blOut = Aabb(loX: b.minX, loY: b.minY, hiX: b.midpoint.x, hiY: b.midpoint.y)
		let brOut = Aabb(loX: b.midpoint.x, loY: b.minY, hiX: b.maxX, hiY: b.midpoint.y)
		return (tlOut, trOut, blOut, brOut)
	}
}

func splitNode(_ node: QuadNode) -> QuadNode {
	let subCells = node.subcells()
	return QuadNode.Node(bounds: node.bounds, values: [],
												tl: .Empty(bounds: subCells.tl),
												tr: .Empty(bounds: subCells.tr),
												bl: .Empty(bounds: subCells.bl),
												br: .Empty(bounds: subCells.br))
}

struct QuadTree {
	var root: QuadNode
	let maxDepth: Int
	
	init(minX: Float, minY: Float, maxX: Float, maxY: Float, maxDepth: Int) {
		let emptyRoot = QuadNode.Empty(bounds: Aabb(loX: minX, loY: minY, hiX: maxX, hiY: maxY))
		self.root = splitNode(emptyRoot)
		self.maxDepth = maxDepth
	}
	
	mutating func insert(value: Int, region: Aabb) {
		guard root.contains(region: region) else {
			print("Value \(value) lies outside quadtree bounds: \(region)")
			return
		}
		(root, _) = quadInsert(value, region: region, into: root, depth: 1, maxDepth: maxDepth)
	}
	
	mutating func remove(value: Int) {
		root = quadRemove(value, from: root)
	}
	
	func query(search: Aabb) -> Set<Int> {
		return quadQuery(search: search, in: root)
	}
}

/// Also need a point-qtree...

func quadInsert(_ value: Int, region: Aabb, into node: QuadNode, depth: Int, maxDepth: Int) -> (QuadNode, Int) {
	switch (node) {
	case .Empty:
		// Convert leaf to inner node and keep inserting
		let newNode = splitNode(node)
		return quadInsert(value, region: region, into: newNode, depth: depth, maxDepth: maxDepth)
	case .Node(let bounds, var values, var tl, var tr, var bl, var br):
		let nextDepth = depth + 1
		// If there's room below:
		if (nextDepth <= maxDepth) {
			func insertValueInto(_ target: QuadNode) -> (QuadNode, Int) {
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

func quadRemove(_ value: Int, from node: QuadNode) -> QuadNode {
	var result: QuadNode
	switch (node) {
	case .Empty:
		// No effect
		return node
	case .Node(let bounds, var values, var tl, var tr, var bl, var br):
		if values.contains(value) {
			// Value found, update the node
			values.remove(value)
			result = .Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
		} else {
			// Look in subcells and update with result
			tl = quadRemove(value, from: tl)
			tr = quadRemove(value, from: tr)
			bl = quadRemove(value, from: bl)
			br = quadRemove(value, from: br)
			result = .Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
		}
		if case (.Empty, .Empty, .Empty, .Empty) = (tl, tr, bl, br), values.isEmpty {
			// If the subtree is now completely empty, close this node too
			result = .Empty(bounds: bounds)
		}
		return result
	}
}

func quadQuery(search: Aabb, in node: QuadNode) -> Set<Int> {
	switch (node) {
	case .Empty:
		return Set<Int>()
	case let .Node(_, values, tl, tr, bl, br):
		if node.intersects(search: search) {
			var subtreeValues = Set<Int>(values)
			subtreeValues.formUnion(quadQuery(search: search, in: tl))
			subtreeValues.formUnion(quadQuery(search: search, in: tr))
			subtreeValues.formUnion(quadQuery(search: search, in: bl))
			subtreeValues.formUnion(quadQuery(search: search, in: br))
			return subtreeValues
		} else {
			return Set<Int>()
		}
	}
}
