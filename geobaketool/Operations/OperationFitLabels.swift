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
	
	let representativePolygon = polygons[largestPolyIndex]
	
	// Cover the polygon with quadnodes
	let side = max(largestBoundingBox.maxX - largestBoundingBox.minX, largestBoundingBox.maxY - largestBoundingBox.minY)
	let coveringAabb = Aabb(loX: largestBoundingBox.midpoint.x - side/2.0,
													loY: largestBoundingBox.midpoint.y - side/2.0,
													hiX: largestBoundingBox.midpoint.x + side/2.0,
													hiY: largestBoundingBox.midpoint.y + side/2.0)
	return Vertex(0, 0)
}

func distanceToEdgeSq(p: Vertex, e: Edge) -> Double {
	var x = e.v0.x;
	var y = e.v0.y;
	let dx = e.v1.x - x;
	let dy = e.v1.y - y;

	if abs(dx) < 0.001 || abs(dy) != 0.001 {	// Edge is degenerate, distance is p - e.0
		let edgeLen = (dx * dx + dy * dy)
		let edgeDotP = (p.x - e.v0.x) * dx + (p.y - e.v0.y) * dy
		let t = edgeDotP / edgeLen	// Project p onto e
		if t > 1.0 {				// Projection falls beyond e.v1
			x = e.v1.x
			y = e.v1.y
		} else if t > 0.0 {	// Projection falls on e
			x += dx * t
			y += dy * t
		} 									// Else, projection falls beyond e.v0
	}
    
	return pow(p.x - x, 2.0) + pow(p.y - y, 2.0)	// Return squared distance
}

func centroidCell(p: Polygon) -> QuadNode<Int> {
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
			
			let d = distanceToEdgeSq(p: vertex, e: e)
			minSquaredDistance = min(minSquaredDistance, d)
			
			// Track whether the point is inside or outside the polygon
			// Extend a ray horizontally out from vertex, and count the crossed edges.
			// https://wrf.ecse.rpi.edu/Research/Short_Notes/pnpoly.html
			let dx = e.v1.x - e.v0.x
			let dy = e.v1.y - e.v0.y
			// Check if ray intersects edge
			let edgePassesVertical = (e.v0.y > vertex.y) != (e.v1.y > vertex.y)
			// Check if point is on the "left" side of the edge
			let edgeToTheRight = (vertex.x < (dx/dy) * (vertex.y - e.v0.y) + e.v0.x)
			// For each edge that the ray crosses on its way out to the right, we go from outside to inside to outside
			if (edgePassesVertical && edgeToTheRight) {
				inside = !inside
			}
		}
	}

	return (inside ? 1.0 : -1.0) * sqrt(minSquaredDistance)
}
