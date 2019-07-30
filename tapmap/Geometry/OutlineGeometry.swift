//
//  OutlineGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

func vectorAdd(_ v0: Vertex, _ v1: Vertex) -> Vertex {
	return Vertex(v1.x + v0.x, v1.y + v0.y)
}

func vectorSub(_ v0: Vertex, _ v1: Vertex) -> Vertex {
	return Vertex(v0.x - v1.x, v0.y - v1.y)
}

func normalize(_ v: Vertex) -> Vertex {
	let m = sqrt(v.x * v.x + v.y * v.y)
	return Vertex(v.x / m, v.y / m)
}

func normal(_ v: Vertex) -> Vertex {
	return normalize(Vertex(-v.y, v.x))
}

func dotProduct(_ v0: Vertex, _ v1: Vertex) -> Vertex.Precision {
	return v0.x * v1.x + v0.y * v1.y
}

func anchorTangent(v0: Vertex, v1: Vertex, v2: Vertex) -> Vertex {
	return normalize(vectorAdd(normalize(vectorSub(v1, v0)), normalize(vectorSub(v2, v1))))
}

typealias Rib = (p: Vertex, miterIn: Vertex, miterOut: Vertex)
func makeRib(_ v0: Vertex, _ v1: Vertex) -> Rib {
	let edge = normalize(vectorSub(v1, v0))
	let n = normal(edge)
	let inner = Vertex(-n.x, -n.y)
	let outer = Vertex(+n.x, +n.y)
	
	return Rib(v0, inner, outer)
}

func makeMiterRib(_ v0: Vertex, _ v1: Vertex, _ v2: Vertex) -> Rib {
	let incomingNormal = normal(vectorSub(v1, v0))
	let tangent = anchorTangent(v0: v0, v1: v1, v2: v2)
	let miter = Vertex(-tangent.y, tangent.x)
	var miterLength = 1.0 / dotProduct(miter, incomingNormal)
	miterLength = min(miterLength, 2.0)
	
	let inner = Vertex(-miter.x * miterLength, -miter.y * miterLength)
	let outer = Vertex(+miter.x * miterLength, +miter.y * miterLength)
	
	return Rib(v1, inner, outer)
}

func makeMiteredTriStrip(ribs: [Rib]) -> [OutlineVertex] {
	return ribs.reduce([]) { (acc: [OutlineVertex], cur) in
		let innerFatVertex = OutlineVertex(cur.p.x, cur.p.y, miterX: cur.miterIn.x, miterY: cur.miterIn.y)
		let outerFatVertex = OutlineVertex(cur.p.x, cur.p.y, miterX: cur.miterOut.x, miterY: cur.miterOut.y)
		return acc + [innerFatVertex, outerFatVertex]
	}
}

func generateOutlineGeometry(outline: [Vertex]) -> [OutlineVertex] {
	guard outline.count >= 2 else { return [] }
	
	let firstRib = makeRib(outline[0], outline[1])
	var miterRibs: [Rib] = []
	for i in 1..<outline.count - 1 {
		let miterRib = makeMiterRib(outline[i - 1], outline[i], outline[i + 1])
		miterRibs.append(miterRib)
	}
	
	var lastRib = makeRib(outline[outline.count - 1], outline[outline.count - 2])
	swap(&lastRib.miterIn, &lastRib.miterOut)	// lastRib will have inverted normal, so flip it back
	
	let ribs = [firstRib] + miterRibs + [lastRib]
	return makeMiteredTriStrip(ribs: ribs)
}

func generateClosedOutlineGeometry(outline: [Vertex], width: Vertex.Precision) -> [OutlineVertex] {
	guard outline.count >= 3 else { return [] }
	
	let firstRib = makeMiterRib(outline.last!, outline.first!, outline[1])
	var miterRibs: [Rib] = []
	for i in 1..<outline.count - 1 {
		let miterRib = makeMiterRib(outline[i - 1], outline[i], outline[i + 1])
		miterRibs.append(miterRib)
	}
	
	let endRib = makeMiterRib(outline[outline.count - 2], outline.last!, outline.first!)
	let closeRib = makeMiterRib(outline[outline.count - 1], outline.first!, outline[1])
	
	let ribs = [firstRib] + miterRibs + [endRib, closeRib]
	return makeMiteredTriStrip(ribs: ribs)
}

