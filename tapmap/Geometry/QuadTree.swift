//
//  QuadTree.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-26.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

typealias Bounds = (minX: Float, minY: Float, maxX: Float, maxY: Float)

indirect enum QuadNode {
	case Node(bounds: Bounds, values: [Int], tl: QuadNode, tr: QuadNode, bl: QuadNode, br: QuadNode)
	case Empty(bounds: Bounds)
	
	func contains(region: Bounds) -> Bool {
		switch self {
		case let .Node(bounds, _, _, _, _, _), let .Empty(bounds):
		return (region.minX >= bounds.minX && region.minY >= bounds.minY &&
						region.maxX < bounds.maxX && region.maxY < bounds.maxY)
	}
}

struct QuadTree {
	var root: QuadNode
	
	init(minX: Float, minY: Float, maxX: Float, maxY: Float) {
		root = .Empty(bounds: (minX, minY, maxX, maxY))
	}
}

func splitBounds(b: Bounds) -> (tl: Bounds, tr: Bounds, bl: Bounds, br: Bounds) {
	let tlOut = Bounds(minX: b.minX,
										 maxX: (b.minX + b.maxX) / 2.0,
										 minY: b.minY,
										 maxY: (b.minY + b.maxY) / 2.0)
	let trOut = Bounds(minX: (b.minX + b.maxX) / 2.0,
										 maxX: b.maxX,
										 minY: b.minY,
										 maxY: (b.minY + b.maxY) / 2.0)
	let blOut = Bounds(minX: b.minX,
										 maxX: (b.minX + b.maxX) / 2.0,
										 minY: (b.minY + b.maxY) / 2.0,
										 maxY: b.maxY)
	let brOut = Bounds(minX: (b.minX + b.maxX) / 2.0,
										 maxX: b.maxX,
										 minY: (b.minY + b.maxY) / 2.0,
										 maxY: b.maxY)
	return (tlOut, trOut, blOut, brOut)
}

func quadInsert(hash: Int, region: Bounds, into node: QuadNode) -> QuadNode {
	
	switch (node) {
	case .Empty(let bounds):
		let subCells = splitBounds(b: bounds)
		return .Node(bounds: bounds, values: [hash],
								 tl: .Empty(bounds: subCells.tl),
								 tr: .Empty(bounds: subCells.tr),
								 bl: .Empty(bounds: subCells.bl),
								 br: .Empty(bounds: subCells.br))
	case .Node(let bounds, var values, var tl, var tr, var bl, var br):
		if (tl.contains(region: region)) {
			tl = quadInsert(hash: hash, region: region, into: tl)
		} else if (tr.contains(region: region)) {
			tr = quadInsert(hash: hash, region: region, into: tr)
		} else if (bl.contains(region: region)) {
			bl = quadInsert(hash: hash, region: region, into: bl)
		} else if (br.contains(region: region)) {
			br = quadInsert(hash: hash, region: region, into: br)
		} else {
			values.append(hash)
		}
		return .Node(bounds: bounds, values: values, tl: tl, tr: tr, bl: bl, br: br)
	}
}
