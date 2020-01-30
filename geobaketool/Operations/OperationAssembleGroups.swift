//
//  OperationCollectBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-25.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class OperationAssembleGroups : Operation {
	let input : Set<ToolGeoFeature>
	var output : Set<ToolGeoFeature>?
	let report : ProgressReport
	let sourceLevel : ToolGeoFeature.Level
	let targetLevel : ToolGeoFeature.Level
	
	init(parts: Set<ToolGeoFeature>,
			 sourceLevel: ToolGeoFeature.Level,
			 targetLevel: ToolGeoFeature.Level,
			 reporter: @escaping ProgressReport) {
		input = parts
		report = reporter
		output = input
		self.sourceLevel = sourceLevel
		self.targetLevel = targetLevel
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		print("Assembling parts (\(sourceLevel.rawValue)) into groups (\(targetLevel.rawValue))")
		var partGroups = [String : Set<ToolGeoFeature>]()
		for part in input {
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
		var groupFeatures = Set<ToolGeoFeature>()
		for partList in partGroups {
			let contourRings = partList.value.flatMap { $0.polygons.map { $0.exteriorRing } }
			
			let groupRings = buildContourOf(rings: contourRings, report: report, partList.key)
			print("Collected \(contourRings.count) part rings into \(groupRings.count) group rings.")
			let geometry = groupRings.map { Polygon(exteriorRing: $0, interiorRings: []) }
			let continent = ToolGeoFeature(level: targetLevel,	// $ Pass it down here
																		 polygons: geometry,
																		 tessellation: nil,
																		 places: nil,
																		 children: nil,
																		 stringProperties: ["name" : partList.key],
																		 valueProperties: [:])
			groupFeatures.insert(continent)
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
	var workEdges: [Int : Edge] = [:]
	
	for e in edges {
		workEdges[e.v0.hashValue] = e
	}
	
	// Select the starting vertex
	workVertices.append(edges.first!.v0)
	let numEdges = edges.count
	while (!workEdges.isEmpty) {
		// Find the edge leading from the last vertex
		let nextEdge = Edge(workVertices.last!, workVertices.last!)
		if let foundEdge = workEdges[nextEdge.v0.hashValue] {
			workVertices.append(foundEdge.v1)
			workEdges.removeValue(forKey: foundEdge.v0.hashValue)
		} else {
			// If there is no edge leading away, this ring has closed. Restart.
			rings.append(VertexRing(vertices: workVertices))
			if let restartEdge = workEdges.first?.value {
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
