//
//  QuadTree.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

indirect enum QuadNode {
	case Node(bounds: Aabb, values: [Int], tl: QuadNode, tr: QuadNode, bl: QuadNode, br: QuadNode)
	case Empty(bounds: Aabb)
	
	func contains(region: Aabb) -> Bool {
		switch self {
		case let .Node(bounds, _, _, _, _, _), let .Empty(bounds):
			return (region.minX >= bounds.minX && region.minY >= bounds.minY &&
							region.maxX < bounds.maxX && region.maxY < bounds.maxY)
		}
	}
}

struct QuadTree {
	var root: QuadNode
	var depth: Int
	let maxDepth: Int
	
	init(minX: Float, minY: Float, maxX: Float, maxY: Float, maxDepth: Int) {
		let emptyRoot = QuadNode.Empty(bounds: Aabb(loX: minX, loY: minY, hiX: maxX, hiY: maxY))
		self.root = splitNode(emptyRoot)
		self.depth = 1
		self.maxDepth = maxDepth
	}
	
	mutating func insert(value: Int, region: Aabb) {
		guard root.contains(region: region) else {
			print("Value \(value) lies outside quadtree bounds: \(region)")
			return
		}
		(root, depth) = quadInsert(value, region: region, into: root, depth: 1, maxDepth: maxDepth)
	}
}

func splitBounds(b: Aabb) -> (tl: Aabb, tr: Aabb, bl: Aabb, br: Aabb) {
	let tlOut = Aabb(loX: b.minX, loY: b.minY, hiX: b.midpoint.x, hiY: b.midpoint.y)
	let trOut = Aabb(loX: b.midpoint.x, loY: b.minY, hiX: b.maxX, hiY: b.midpoint.y)
	let blOut = Aabb(loX: b.minX, loY: b.midpoint.y, hiX: b.midpoint.x, hiY: b.maxY)
	let brOut = Aabb(loX: b.midpoint.x, loY: b.midpoint.y, hiX: b.maxX, hiY: b.maxY)
	return (tlOut, trOut, blOut, brOut)
}

func splitNode(_ node: QuadNode) -> QuadNode {
	switch (node) {
	case let .Node(bounds, _, _, _, _, _), let .Empty(bounds):
		let subCells = splitBounds(b: bounds)
		return QuadNode.Node(bounds: bounds, values: [],
													tl: .Empty(bounds: subCells.tl),
													tr: .Empty(bounds: subCells.tr),
													bl: .Empty(bounds: subCells.bl),
													br: .Empty(bounds: subCells.br))
	}
}

/// Also need a point-qtree...
/// Put subcells into an array

func quadInsert(_ value: Int, region: Aabb, into node: QuadNode, depth: Int, maxDepth: Int) -> (QuadNode, Int) {
	switch (node) {
	case .Empty:
		let newNode = splitNode(node)
		return quadInsert(value, region: region, into: newNode, depth: depth, maxDepth: maxDepth)
	case .Node(let bounds, var values, var tl, var tr, var bl, var br):
		let nextDepth = depth + 1
		if (nextDepth <= maxDepth) {
			func insertValueInto(_ target: QuadNode) -> (QuadNode, Int) {
				quadInsert(value, region: region, into: target, depth: nextDepth, maxDepth: maxDepth)
			}
			let newDepth: Int
			if      (tl.contains(region: region)) { (tl, newDepth) = insertValueInto(tl)	}
			else if (tr.contains(region: region)) { (tr, newDepth) = insertValueInto(tr) }
			else if (bl.contains(region: region)) { (bl, newDepth) = insertValueInto(bl) }
			else if (br.contains(region: region)) { (br, newDepth) = insertValueInto(br) }
			else {
				newDepth = depth
				values.append(value)
			}
			let node = QuadNode.Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
			return (node, newDepth)
		} else {
			values.append(value)
			let node = QuadNode.Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
			return (node, depth)
		}
	}
}
