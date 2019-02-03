//
//  KDTree.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-03.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

// MARK: Structures
enum SplitDirection {
	case x
	case y
	
	func flip() -> SplitDirection {
		if case .x = self { return .y } else { return .x }
	}
}

indirect enum KDNode {
	case Empty
	case Split(KDNode, Vertex, KDNode, SplitDirection)
	
	init() { self = .Empty }
	init(left: KDNode, _ p: Vertex, right: KDNode, _ d: SplitDirection) {
		self = .Split(left, p, right, d)
	}
	
	func replaceLeft(newLeft: KDNode) -> KDNode {
		guard case let .Split(_, v, r, d) = self else { return .Empty }
		return KDNode(left: newLeft, v, right: r, d)
	}
	
	func replaceRight(newRight: KDNode) -> KDNode {
		guard case let .Split(l, v, _, d) = self else { return .Empty }
		return KDNode(left: l, v, right: newRight, d)
	}
}

// MARK: Helpers
fileprivate func kdCompare(u: Vertex, v: Vertex, d: SplitDirection) -> Bool {
	switch d {
	case .x: return u.x < v.x
	case .y: return u.y < v.y
	}
}

fileprivate func sqDist(v: Vertex, q: Vertex) -> Double {
	return Double(pow(v.x - q.x, 2.0) + pow(v.y - q.y, 2.0))
}

fileprivate func bbDist(v: Vertex, bb: CGRect) -> Double {
	let dx = max(abs(CGFloat(v.x) - bb.midX) - bb.width / 2.0, 0.0)
	let dy = max(abs(CGFloat(v.y) - bb.midY) - bb.height / 2.0, 0.0)
	return Double(dx * dx + dy * dy)
}

fileprivate func bbTrimLow(d: SplitDirection, value: Float, bb: CGRect) -> CGRect {
	if case .x = d {
		return CGRect(x: bb.minX, y: bb.minY, width: bb.width / 2.0, height: bb.height)
	} else {
		return CGRect(x: bb.minX, y: bb.minY, width: bb.width, height: bb.height / 2.0)
	}
}

fileprivate func bbTrimHigh(d: SplitDirection, value: Float, bb: CGRect) -> CGRect {
	if case .x = d {
		return CGRect(x: bb.midX, y: bb.minY, width: bb.width / 2.0, height: bb.height)
	} else {
		return CGRect(x: bb.minX, y: bb.midY, width: bb.width, height: bb.height / 2.0)
	}
}

// MARK: Algoritm
func kdInsert(v: Vertex, n: KDNode, d: SplitDirection = .x) -> KDNode {
	switch n {
	case .Empty: return KDNode(left: .Empty, v, right: .Empty, d)
	case .Split(let left, let a, let right, let d):
		guard a != v else { return n }
		if kdCompare(u: v, v: a, d: d) {
			return n.replaceLeft(newLeft: kdInsert(v: v, n: left, d: d.flip()))
		} else {
			return n.replaceRight(newRight: kdInsert(v: v, n: right, d: d.flip()))
		}
	}
}

typealias Result = (bestPoint: Vertex, bestDistance: Double)

func kdFindNearest(query q: Vertex, node: KDNode,
									 d: SplitDirection, aabb: CGRect,
									 result: Result) -> Result {
	switch node {
	case .Empty: return result
	case .Split(let l, let v, let r, let d):
		// Early reject if this subspace is worse than current best
		if bbDist(v: v, bb: aabb) > result.bestDistance {
			return result
		}
		
		var newResult = result
		let dist = sqDist(v: q, q: v)
		if dist < result.bestDistance {
			newResult.bestPoint = v
			newResult.bestDistance = dist
		}
		
		let leftResult: Result
		let rightResult: Result
		if kdCompare(u: q, v: v, d: d) {
			leftResult = kdFindNearest(query: q, node: l, d: d.flip(),
																 aabb: bbTrimLow(d: d, value: v.x, bb: aabb),
																 result: newResult)
			rightResult = kdFindNearest(query: q, node: r, d: d.flip(),
																	aabb: bbTrimHigh(d: d, value: v.x, bb: aabb),
																	result: newResult)
		} else {
			rightResult = kdFindNearest(query: q, node: r, d: d.flip(),
																	aabb: bbTrimHigh(d: d, value: v.x, bb: aabb),
																	result: newResult)
			leftResult = kdFindNearest(query: q, node: l, d: d.flip(),
																 aabb: bbTrimLow(d: d, value: v.x, bb: aabb),
																 result: newResult)
		}
		
		if newResult.bestDistance < leftResult.bestDistance && newResult.bestDistance < rightResult.bestDistance {
			return newResult
		} else if leftResult.bestDistance < rightResult.bestDistance {
			return leftResult
		} else {
			return rightResult
		}
	}
}
