//
//  OperationFitLabels.swift
//  geobaketool
//
//  Created by Ivan Milles on 2020-03-03.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class OperationFitLabels : Operation {
	let worldFeatures : Set<ToolGeoFeature>
	
	var output : Set<ToolGeoFeature>
	let report : ProgressReport
	
	init(worldCollection: Set<ToolGeoFeature>,
			 reporter: @escaping ProgressReport) {
		
		worldFeatures = worldCollection
		report = reporter
		
		output = []
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

		for feature in worldFeatures {
			let labelCenter = poleOfInaccessibility(feature.polygons)
			let regionMarker = GeoPlace(location: labelCenter, name: feature.name, kind: .Region, rank: 0)
			let editedPlaces = feature.places!.union([regionMarker])
			let updatedFeature = ToolGeoFeature(level: feature.level,
																					polygons: feature.polygons,
																					tessellation: feature.tessellation,
																					places: editedPlaces,
																					children: feature.children,
																					stringProperties: feature.stringProperties,
																					valueProperties: feature.valueProperties)
			output.insert(updatedFeature)
		}
	}
}

// Mapbox: new algorithm for finding a visual center of a polygon
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
		if candidateDistance < bestDistance {
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
	var area = 0.0
	for i in 0..<ring.vertices.count {
		let e = Edge(ring.vertices[i],
								 ring.vertices[(i + 1) % ring.vertices.count])
		// Shoelace formula
		let determinant = (e.v0.x * e.v1.y - e.v1.x * e.v0.y)
		cx += (e.v0.x + e.v1.x) * determinant
		cy += (e.v0.y + e.v1.y) * determinant
		area += determinant
	}
	
	let centroid = Vertex(cx / (6.0 * area), cy / (6.0 * area))
	
	return .Empty(bounds: Aabb(loX: centroid.x, loY: centroid.y, hiX: centroid.x, hiY: centroid.y))
}

func signedDistance(from vertex: Vertex, to polygon: Polygon) -> Double {
	var inside = false
	var minSquaredDistance = Double.greatestFiniteMagnitude
	
	let rings = [polygon.exteriorRing] + polygon.interiorRings
	for ring in rings {
		for i in 0..<polygon.exteriorRing.vertices.count {
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
