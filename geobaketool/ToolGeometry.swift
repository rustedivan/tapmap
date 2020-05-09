//
//  ToolGeometry.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-11-30.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import LibTessSwift

// MARK: Structures
struct Vertex : Equatable, Hashable {
	typealias Precision = Double
	
	let x: Precision
	let y: Precision
	
	init(_ _x: Precision, _ _y: Precision) { x = _x; y = _y; }
	
	var quantized : (Int64, Int64) {
		let quant: Precision = 1e-3
		return (Int64(floor(x / quant)), Int64(floor(y / quant)))
	}
	
	static func ==(lhs: Vertex, rhs: Vertex) -> Bool {
		return lhs.quantized == rhs.quantized
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(quantized.0)
		hasher.combine(quantized.1)
	}
}

struct Edge : Equatable, Hashable {
	let v0: Vertex
	let v1: Vertex
	
	init(_ _v0: Vertex, _ _v1: Vertex) {
		v0 = _v0
		v1 = _v1
	}
	
	static func ==(lhs: Edge, rhs: Edge) -> Bool {
		return (lhs.v0 == rhs.v0 && lhs.v1 == rhs.v1) || (lhs.v0 == rhs.v1 && lhs.v1 == rhs.v0)
	}
	
	func hash(into hasher: inout Hasher) {
		let orderedHashes = [v0.hashValue, v1.hashValue].sorted()
		hasher.combine(orderedHashes)
	}
}

struct VertexRing : Codable {
	var vertices: [Vertex]
	var contour : [CVector3] {
		return vertices.map { CVector3(x: Float($0.x), y: Float($0.y), z: 0.0) }
	}
	
	init(vertices inVerts: [Vertex]) {
		vertices = inVerts
		if vertices.first == vertices.last {
			vertices.removeLast()
		}
	}
	
	init(edges: [Edge]) {
		self.init(vertices: edges.map { $0.v0 })
	}
}

struct Polygon: Codable {
	var exteriorRing: VertexRing
	var interiorRings: [VertexRing]
	let area: Double
	
	init(exterior: VertexRing, interiors: [VertexRing]) {
		exteriorRing = exterior
		interiorRings = interiors
		
		var a = 0.0
		for i in 0..<exteriorRing.vertices.count {
			let e = Edge(exteriorRing.vertices[i],
									 exteriorRing.vertices[(i + 1) % exteriorRing.vertices.count])
			// Shoelace formula
			let determinant = (e.v0.x * e.v1.y - e.v1.x * e.v0.y)
			a += determinant
		}
		area = a
	}
	
	func totalVertexCount() -> Int {
			return exteriorRing.vertices.count +
						 interiorRings.reduce(0) { $0 + $1.vertices.count }
	}
}

// MARK: Algorithms

func snapPointToEdge(p: Vertex, threshold: Double, edge: (a : Vertex, b : Vertex)) -> (Vertex, Double) {
	let a = edge.a
	let b = edge.b
	let ab = Vertex(b.x - a.x, b.y - a.y)
	let ap = Vertex(p.x - a.x, p.y - a.y)
	let segLenSqr = ab.x * ab.x + ab.y * ab.y
	let t = (ap.x * ab.x + ap.y * ab.y) / segLenSqr
	
	// If the closest point is within the segment...
	if t >= 0.0 && t <= 1.0 {
		// Find the closest point
		let q = Vertex(a.x + ab.x * t, a.y + ab.y * t)
		// Calculate distance to closest point on the line
		let pq = Vertex(p.x - q.x, p.y - q.y)
		let dSqr = pq.x * pq.x + pq.y * pq.y
		if dSqr < threshold * threshold {
			return (q, dSqr)
		}
	}
	
	return (p, Double.greatestFiniteMagnitude)
}

struct EdgeIndices : Hashable {
	let lo, hi: Int
	init(_ i0: UInt32, _ i1: UInt32) {
		lo = Int(min(i0, i1))
		hi = Int(max(i0, i1))
	}
}

func tessellate(_ feature: ToolGeoFeature) -> GeoTessellation? {
	guard let tess = TessC() else {
		print("Could not init TessC")
		return nil
	}
	
	for polygon in feature.polygons {
		let exterior = polygon.exteriorRing.contour
		tess.addContour(exterior)
		let interiorContours = polygon.interiorRings.map{ $0.contour }
		for interior in interiorContours {
			tess.addContour(interior)
		}
	}
	
	let t: (vertices: [CVector3], indices: [Int])
	do {
		t = try tess.tessellate(windingRule: .evenOdd,
														elementType: ElementType.polygons,
														polySize: 3,
														vertexSize: .vertex2)
	} catch {
		return nil
	}

	var aabb = Aabb()
	var midpoint: (Vertex.Precision, Vertex.Precision) = (0.0, 0.0)
	let regionVertices = t.vertices.map { (v: CVector3) -> Vertex in
		// Calculate the aabb while we're passing through
		aabb = Aabb(loX: min(Vertex.Precision(v.x), aabb.minX),
								loY: min(Vertex.Precision(v.y), aabb.minY),
								hiX: max(Vertex.Precision(v.x), aabb.maxX),
								hiY: max(Vertex.Precision(v.y), aabb.maxY))
		midpoint.0 += Vertex.Precision(v.x)
		midpoint.1 += Vertex.Precision(v.y)
		return Vertex(Vertex.Precision(v.x), Vertex.Precision(v.y))
	}
	midpoint.0 /= Double(regionVertices.count)
	midpoint.1 /= Double(regionVertices.count)
	
	let indices = t.indices.map { UInt16($0) }
	
	let visualCenter = poleOfInaccessibility(feature.polygons)

	return GeoTessellation(vertices: regionVertices, indices: indices, contours: feature.polygons.map { $0.exteriorRing }, aabb: aabb, visualCenter: visualCenter)
}

// MARK: MapBox visual center algorithm
// MapBox: new algorithm for finding a visual center of a polygon
//   Vladimir Agafonkin (blog.mapbox.com)
struct NodeDistances: Codable, Hashable {
	let toPolygon: Double
	let maxInNode: Double
}
typealias LabellingNode = QuadNode<NodeDistances>

func poleOfInaccessibility(_ polygons: [Polygon]) -> Vertex {
	// First, select the largest polygon to focus on (rough estimate, just to get rid of islands
	var largestBoundingBox = Aabb()
	var largestPolyArea = 0.0
	var largestPolyIndex = -1
	for (i, p) in polygons.enumerated() {
		let boundingBox = p.exteriorRing.vertices.reduce(Aabb()) { (acc, v) -> Aabb in
			return Aabb(loX: min(v.x, acc.minX),
									loY: min(v.y, acc.minY),
									hiX: max(v.x, acc.maxX),
									hiY: max(v.y, acc.maxY))
		}
		let boxArea = (boundingBox.maxX - boundingBox.minX) * (boundingBox.maxY - boundingBox.minY)
		if (boxArea > largestPolyArea) {
			largestBoundingBox = boundingBox
			largestPolyArea = boxArea
			largestPolyIndex = i
		}
	}
	
	if (largestPolyArea <= 0.01) {
		return largestBoundingBox.midpoint
	}
	
	let polygon = polygons[largestPolyIndex]	// This is the largest polygon in the region, so target that.
	
	// Seed the search with one square quadnode that covers the polygon
	let side = max(largestBoundingBox.maxX - largestBoundingBox.minX, largestBoundingBox.maxY - largestBoundingBox.minY)
	let coveringAabb = Aabb(loX: largestBoundingBox.midpoint.x - side/2.0,
													loY: largestBoundingBox.midpoint.y - side/2.0,
													hiX: largestBoundingBox.midpoint.x + side/2.0,
													hiY: largestBoundingBox.midpoint.y + side/2.0)
	let fullCover = calculateNodeDistances(quadNode: LabellingNode.Empty(bounds: coveringAabb), polygon: polygon)
	var nodeQueue = Array<LabellingNode>([fullCover])
	
	let startNode = centroidCell(p: polygon) // Initial guess on the polygon centroid
	var bestNode = calculateNodeDistances(quadNode: startNode, polygon: polygon)
	guard case let .Node(_, bestDistances, _, _, _, _) = bestNode else { exit(1) }
	var bestDistance = bestDistances.first!.toPolygon
	
	// While there are nodes in the queue to be investigated
	while let node = nodeQueue.popLast() {
		// Check if this node is better than the best so far
		guard case let QuadNode.Node(_, candidateDistances, _, _, _, _) = node else { continue }
		let candidateDistance = candidateDistances.first!.toPolygon
		if candidateDistance > bestDistance {
			bestNode = node
			bestDistance = candidateDistance
		}
		
		// This node has no possible children further away from the polygon's edge than the best so far
		if (candidateDistances.first!.maxInNode - bestDistance <= 1.0) { continue }
		
		// Split up into four children and queue them up
		let subCells = node.subnodes()
		let subNodes = [subCells.tl, subCells.tr,
										subCells.bl, subCells.br]
			.map { calculateNodeDistances(quadNode: $0, polygon: polygon) }
		nodeQueue.append(contentsOf: subNodes)
		nodeQueue.sort(by: sortLabellingNode)	// Emulate a priority queue
	}
	
	return bestNode.bounds.midpoint
}

func calculateNodeDistances(quadNode: LabellingNode, polygon: Polygon) -> LabellingNode {
	let subNodes = quadNode.subnodes()
	let distanceToPolygon = signedDistance(from: quadNode.bounds.midpoint, to: polygon)
	let max = distanceToPolygon + (quadNode.bounds.maxX - quadNode.bounds.minX) * sqrt(2.0)
	let nodeDistances = NodeDistances(toPolygon: distanceToPolygon, maxInNode: max)
	return QuadNode.Node(bounds: quadNode.bounds,
											 values: Set([nodeDistances]),
											 tl: subNodes.tl, tr: subNodes.tr,
											 bl: subNodes.bl, br: subNodes.br)
}

func sortLabellingNode(lhs: LabellingNode, rhs: LabellingNode) -> Bool {
	guard case let QuadNode.Node(_, lhsDistance, _, _, _, _) = lhs,
				case let QuadNode.Node(_, rhsDistance, _, _, _, _) = rhs else {
		return true
	}
	return lhsDistance.first!.toPolygon < rhsDistance.first!.toPolygon
}

func distanceToEdgeSq(p: Vertex, e: Edge) -> Double {
	var v = e.v0
	let d = Vertex(e.v1.x - v.x, e.v1.y - v.y)

	if abs(d.x) < 0.001 || abs(d.y) != 0.001 {	// Edge is degenerate, distance is p - e.0
		let edgeLen = (d.x * d.x + d.y * d.y)
		let edgeDotP = (p.x - e.v0.x) * d.x + (p.y - e.v0.y) * d.y
		let t = edgeDotP / edgeLen	// Project p onto e
		if t > 1.0 {				// Projection falls beyond e.v1
			v = e.v1
		} else if t > 0.0 {	// Projection falls on e
			v = Vertex(v.x + d.x * t, v.y + d.y * t)
		} 									// Else, projection falls beyond e.v0
	}
    
	return pow(p.x - v.x, 2.0) + pow(p.y - v.y, 2.0)	// Return squared distance
}

func centroidCell(p: Polygon) -> LabellingNode {
	let ring = p.exteriorRing
	
	var cx = 0.0
	var cy = 0.0
	for i in 0..<ring.vertices.count {
		let e = Edge(ring.vertices[i],
								 ring.vertices[(i + 1) % ring.vertices.count])
		// Shoelace formula
		let determinant = (e.v0.x * e.v1.y - e.v1.x * e.v0.y)
		cx += (e.v0.x + e.v1.x) * determinant
		cy += (e.v0.y + e.v1.y) * determinant
	}
	
	let centroid = Vertex(cx / (6.0 * p.area), cy / (6.0 * p.area))
	
	return .Empty(bounds: Aabb(loX: centroid.x, loY: centroid.y, hiX: centroid.x, hiY: centroid.y))
}

func signedDistance(from vertex: Vertex, to polygon: Polygon) -> Double {
	var inside = false
	var minSquaredDistance = Double.greatestFiniteMagnitude
	
	let rings = [polygon.exteriorRing] + polygon.interiorRings
	for ring in rings {
		for i in 0..<ring.vertices.count {
			let e = Edge(ring.vertices[i],
									 ring.vertices[(i + 1) % ring.vertices.count])
			
			let l = distanceToEdgeSq(p: vertex, e: e)
			minSquaredDistance = min(minSquaredDistance, l)
			
			// Track whether the point is inside or outside the polygon
			// Extend a ray horizontally out from vertex, and count the crossed edges.
			// https://wrf.ecse.rpi.edu/Research/Short_Notes/pnpoly.html
			let d = Vertex(e.v1.x - e.v0.x, e.v1.y - e.v0.y)
			// Check if ray intersects edge
			let edgePassesVertical = (e.v0.y > vertex.y) != (e.v1.y > vertex.y)
			// Check if point is on the "left" side of the edge
			let edgeToTheRight = (vertex.x < (d.x/d.y) * (vertex.y - e.v0.y) + e.v0.x)
			// For each edge that the ray crosses on its way out to the right, we go from outside to inside to outside
			if (edgePassesVertical && edgeToTheRight) {
				inside = !inside
			}
		}
	}

	return (inside ? 1.0 : -1.0) * sqrt(minSquaredDistance)
}

