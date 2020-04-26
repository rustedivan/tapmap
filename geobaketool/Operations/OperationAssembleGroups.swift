//
//  OperationCollectBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-25.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class OperationAssembleGroups : Operation {
	let input : ToolGeoFeatureMap
	var output : ToolGeoFeatureMap?
	let report : ProgressReport
	let propertiesMap: [String : ToolGeoFeature.GeoStringProperties]
	let targetLevel : ToolGeoFeature.Level
	
	init(parts: ToolGeoFeatureMap,
			 targetLevel: ToolGeoFeature.Level,
			 properties: [String : ToolGeoFeature.GeoStringProperties],
			 reporter: @escaping ProgressReport) {
		input = parts
		propertiesMap = properties
		report = reporter
		output = input
		self.targetLevel = targetLevel
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		print("Assembling parts into groups (\(targetLevel.rawValue))")
		var partGroups = [String : Set<ToolGeoFeature>]()
		for (_, part) in input {
			let partKey = (targetLevel == ToolGeoFeature.Level.Continent) ? part.continentKey : part.countryKey
			if partGroups[partKey] == nil {
				partGroups[partKey] = []
			}
			partGroups[partKey]!.insert(part)
		}
		
		print("Groups (\(targetLevel.rawValue)):")
		for group in partGroups {
			print("\t\(group.key): \(group.value.count) parts (e.g. \(group.value.first!.name))")
		}
		
		print("Building group contours...")
		var groupFeatures = ToolGeoFeatureMap()
		for partList in partGroups {
			let contourRings = partList.value.flatMap { $0.polygons.flatMap { [$0.exteriorRing] + $0.interiorRings } }

			let groupRings = buildContourOf(rings: contourRings, report: report, partList.key)
			print("Collected \(contourRings.count) part rings into \(groupRings.count) group rings.")
			let geometry = groupRings.map { Polygon(exterior: $0, interiors: []) }	// $ OK, is this a problem?
			let sortedGeometry = geometry.sorted { $0.area < $1.area }
			
			let properties: ToolGeoFeature.GeoStringProperties
			if targetLevel == .Country {
				guard let partProperties = propertiesMap[partList.key] else {
					print("Province \(partList.key) does not belong to any country. Skipping...")
					continue
				}
				properties = partProperties
			} else {
				properties = ["CONTINENT" : partList.key,
											"name" : partList.key]
			}
			if properties.isEmpty { print("Cannot find properties for \(partList.key)") }
			let grouped = ToolGeoFeature(level: targetLevel,
																		 polygons: sortedGeometry,
																		 tessellations: [],
																		 places: nil,
																		 children: nil,
																		 stringProperties: properties,
																		 valueProperties: [:])
			groupFeatures[grouped.geographyId.hashed] = grouped
		}
		
		output = groupFeatures
		
		report(1.0, "Done.", true)
	}
}

func countEdgeCardinalities(rings: [VertexRing]) -> [Edge : Int] {
	var cardinalities: [Edge : Int] = [:]

	for r in rings {
		for i in 0..<r.vertices.count {
			// Construct the next edge in the ring
			let e = Edge(r.vertices[i],
									 r.vertices[(i + 1) % r.vertices.count])

			if cardinalities.keys.contains(e) {
				cardinalities[e]! += 1
			} else {
				cardinalities[e] = 1
			}
		}
	}

	return cardinalities
}

func buildContiguousEdgeRings(edges: [Edge], report: ProgressReport, _ reportName: String = "") -> [VertexRing] {
	var rings: [VertexRing] = []
	var workVertices: [Vertex] = []
	var workEdges: [Int : [Edge]] = [:]
	
	for e in edges {
		workEdges[e.v0.hashValue, default: []].append(e)
	}
	
	// Select the starting vertex
	workVertices.append(edges.first!.v0)
	let numEdges = edges.count
	while (!workEdges.isEmpty) {
		// Find the edge leading from the last vertex
		let nextEdge = Edge(workVertices.last!, workVertices.last!)
		if let foundEdge = workEdges[nextEdge.v0.hashValue]?.popLast() {
			workVertices.append(foundEdge.v1)
			if workEdges[nextEdge.v0.hashValue]!.isEmpty {
				workEdges.removeValue(forKey: foundEdge.v0.hashValue)
			}
		} else {
			// If there is no edge leading away, this ring has closed. Restart.
			rings.append(VertexRing(vertices: workVertices))
			if let restartEdge = workEdges.first?.value.first {
				workVertices = [restartEdge.v0]
			} else {
				break
			}
			
			report(1.0 - (Double(workEdges.count) / Double(numEdges)), "\(reportName) (\(numEdges - workEdges.count)/\(numEdges)", false)
		}
	}
	
	// Insert the last ring too
	rings.append(VertexRing(vertices: workVertices))
	report(1.0, "\(reportName) (\(rings.count) rings)", true)
	
	return rings
}

func buildContourOf(rings: [VertexRing], report: ProgressReport, _ reportName: String = "") -> [VertexRing] {
	let edgeCardinalities = countEdgeCardinalities(rings: rings)
	let contourEdges = edgeCardinalities
		.filter{ $0.1 == 1 }
		.map { $0.0 }
	
	print("Plucked \(contourEdges.count) from edge pool of \(edgeCardinalities.count)")
	
	return buildContiguousEdgeRings(edges: contourEdges, report: report, reportName)
}
