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

protocol PointForm {
	var p : Vertex { get }
}

indirect enum KDNode<Element : PointForm> {
	case Empty
	case Split(KDNode, Element, KDNode, SplitDirection)
	
	init() { self = .Empty }
	init(left: KDNode, _ p: Element, right: KDNode, _ d: SplitDirection) {
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
fileprivate func kdCompare(u: PointForm?, v: PointForm?, d: SplitDirection) -> Bool {
	let accuracy: Float = 0.01
	guard let lhs = u?.p else { return false }
	guard let rhs = v?.p else { return true }
	switch d {
	case .x: return lhs.x < rhs.x - accuracy
	case .y: return lhs.y < rhs.y - accuracy
	}
}

fileprivate func sqDist(v: PointForm, q: PointForm) -> Double {
	return Double(pow(v.p.x - q.p.x, 2.0) + pow(v.p.y - q.p.y, 2.0))
}

fileprivate func bbDist(v: PointForm, bb: CGRect) -> Double {
	let dx = max(abs(CGFloat(v.p.x) - bb.midX) - bb.width / 2.0, 0.0)
	let dy = max(abs(CGFloat(v.p.y) - bb.midY) - bb.height / 2.0, 0.0)
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
func kdEmpty<T:PointForm>(n: KDNode<T>) -> Bool {
	if case .Empty = n {
		return true
	} else {
		return false
	}
}

func kdFindMin<T:PointForm>(n: KDNode<T>, sd: SplitDirection) -> T? {
	switch n {
	case .Empty: return nil
	case .Split(let left, let a, let right, let cd):
		if cd == sd {
			return kdFindMin(n: left, sd: sd)
		} else {
			let minLeft = kdFindMin(n: left, sd: sd)
			let minRight = kdFindMin(n: right, sd: sd)
			return kdCompare(u: minLeft, v: minRight, d: sd) ?
				(kdCompare(u: minLeft, v: a, d: sd) ? minLeft : a) :
				(kdCompare(u: minRight, v: a, d: sd) ? minRight : a)
		}
	}
}

func kdInsert<T:PointForm>(v: T, n: KDNode<T>, d: SplitDirection = .x) -> KDNode<T> {
	switch n {
	case .Empty: return KDNode(left: .Empty, v, right: .Empty, d.flip())
	case .Split(let left, let a, let right, let d):
		guard a.p != v.p else { return n }
		if kdCompare(u: v, v: a, d: d) {
			return n.replaceLeft(newLeft: kdInsert(v: v, n: left, d: d))
		} else {
			return n.replaceRight(newRight: kdInsert(v: v, n: right, d: d))
		}
	}
}

func kdRemove<T:PointForm>(v: T, n: KDNode<T>) -> KDNode<T> {
	switch n {
	case .Empty: return n
	case .Split(let left, let a, let right, let cd):
		if v.p == a.p {
			if case .Split = right {
//				print("Pulling up right branch of \(a.p)")
				let minRight = kdFindMin(n: right, sd: cd)!
//				print("\(cd)Min from right subtree: \(minRight.p)")
				let newRight = kdRemove(v: minRight, n: right)
//				print("Removed min from right subtree:")
//				kdPrint(newRight)
//				print("<== \(a.p)")
				return KDNode(left: left, minRight, right: newRight, cd)
			} else if case .Split = left {
//				print("Pulling up left branch of \(a.p)")
				let newLeft = right
				let minLeft = kdFindMin(n: left, sd: cd)!
//				print("\(cd)Min from new right subtree: \(minLeft.p)")
				let newRight = kdRemove(v: minLeft, n: left)
//				print("Removed min from new right subtree:")
				return KDNode(left: newLeft, minLeft, right: newRight, cd)
				
				
				
				
				
//				print("Pulling up left branch of \(a.p)")
//				let minLeft = kdFindMin(n: left, sd: cd)!
//				print("\(cd)Min from left subtree: \(minLeft.p)")
//				let newRight = kdRemove(v: minLeft, n: left)
//				print("Removed min from left subtree:")
//				kdPrint(newRight)
//				print("<== \(a.p)")
//				return KDNode(left: left, minLeft, right: newRight, cd)
			} else {
//				print("Deleting leaf")
				return .Empty
			}
		} else {
			if kdCompare(u: v, v: a, d: cd) {
				let newLeft = kdRemove(v: v, n: left)
				return n.replaceLeft(newLeft: newLeft)
			} else {
				let newRight = kdRemove(v: v, n: right)
				return n.replaceRight(newRight: newRight)
			}
		}
	}
}

typealias Result<T:PointForm> = (bestPoint: T, bestDistance: Double)

func kdFindNearest<T:PointForm>(query q: T, node: KDNode<T>,
									 d: SplitDirection, aabb: CGRect,
									 result: Result<T>) -> Result<T> {
	switch node {
	case .Empty: return result
	case .Split(let l, let v, let r, let d2):
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
		
		let leftResult: Result<T>
		let rightResult: Result<T>
		if kdCompare(u: q, v: v, d: d2) {
			leftResult = kdFindNearest(query: q, node: l, d: d2.flip(),
																 aabb: bbTrimLow(d: d2, value: v.p.x, bb: aabb),
																 result: newResult)
			rightResult = kdFindNearest(query: q, node: r, d: d2.flip(),
																	aabb: bbTrimHigh(d: d2, value: v.p.x, bb: aabb),
																	result: newResult)
		} else {
			rightResult = kdFindNearest(query: q, node: r, d: d2.flip(),
																	aabb: bbTrimHigh(d: d2, value: v.p.x, bb: aabb),
																	result: newResult)
			leftResult = kdFindNearest(query: q, node: l, d: d2.flip(),
																 aabb: bbTrimLow(d: d2, value: v.p.x, bb: aabb),
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

func kdPrint<T:PointForm>(_ n: KDNode<T>, _ level: Int = 0) {
	let indent = String(Array(repeating: " ", count: level * 2))
	switch(n) {
	case .Empty: print("\(indent)-")
	case .Split(let l, let a, let r, let d):
		print("\(indent)\(d) \(a.p)")
		kdPrint(l, level + 1)
		kdPrint(r, level + 1)
	}
}
