//
//  OperationCollectBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-25.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

func countEdgeCardinalities(rings: [GeoPolygonRing]) -> [(Edge, Int)] {
	var cardinalities: [(Edge, Int)] = []

	for r in rings {
		for i in 0..<r.vertices.count {
			// Construct the next edge in the ring
			let e = Edge(v0: r.vertices[i],
									 v1: r.vertices[(i + 1) % r.vertices.count])
			
			// See if it is already known, and increment the counter if so.
			var edgeFound = false
			for j in 0..<cardinalities.count {
				if cardinalities[j].0 == e {
					cardinalities[j].1 += 1
					edgeFound = true
					break
				}
			}
			
			if !edgeFound {
				cardinalities.append((e, 1))
			}
		}
	}
	
	return cardinalities
}

func buildContiguousEdgeRing(edges: [Edge]) -> GeoPolygonRing? {
	var vertices: [Vertex] = []
	var workEdges = Slice<[Edge]>(edges)
	
	// Select the starting vertex
	vertices.append(workEdges.first!.v0)
	
	while (!workEdges.isEmpty) {
		// Find the edge leading from the last vertex
		if let nextEdge = workEdges.first(where: { $0.v0 == vertices.last }) {
			vertices.append(nextEdge.v1)
			workEdges.removeAll { $0 == nextEdge }
		} else {
			break
		}
	}
	
	return GeoPolygonRing(vertices: vertices)
}

func buildContourOf(rings: [GeoPolygonRing]) -> GeoPolygonRing? {
	let edgeCardinalities = countEdgeCardinalities(rings: rings)
	let contourEdges = edgeCardinalities
		.filter{ $0.1 == 1 }
		.map { $0.0 }
	
	return buildContiguousEdgeRing(edges: contourEdges)
}
