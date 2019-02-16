//
//  OperationCollectBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-25.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class OperationAssembleContinents : Operation {
	let countries : ToolGeoFeatureCollection
	var continents : ToolGeoFeatureCollection?
	let report : ProgressReport
	
	init(countries countriesOfContinent: ToolGeoFeatureCollection,
			 reporter: @escaping ProgressReport) {
		countries = countriesOfContinent
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		print("Assembling continents")
		var continentCountries = [String : Set<ToolGeoFeature>]()
		for country in countries.features {
			if continentCountries[country.continent] == nil {
				continentCountries[country.continent] = []
			}
			continentCountries[country.continent]!.insert(country)
		}
		
		print("Continents:")
		for continent in continentCountries {
			print("\t\(continent.key): \(continent.value.count) countries (e.g. \(continent.value.first!.name))")
		}
		
		print("Building continent contours...")
		var continentFeatures = Set<ToolGeoFeature>()
		for countryList in continentCountries {
			let contourRings = countryList.value.flatMap { $0.polygons.map { $0.exteriorRing } }
			
			let continentRings = buildContourOf(rings: contourRings, report: report, countryList.key)
			print("Collected \(contourRings.count) country rings into \(continentRings.count) continent rings.")
			let geometry = continentRings.map { Polygon(exteriorRing: $0, interiorRings: []) }
			let continent = ToolGeoFeature(level: .Continent,
																 polygons: geometry,
																 tessellation: nil,
																 places: nil,
																 children: nil,
																 stringProperties: ["name" : countryList.key],
																 valueProperties: [:])
			continentFeatures.insert(continent)
		}
		
		continents = ToolGeoFeatureCollection(features: continentFeatures)
		
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
		workEdges[e.p.hashValue] = e
	}
	
	// Select the starting vertex
	workVertices.append(edges.first!.v0)
	let numEdges = edges.count
	while (!workEdges.isEmpty) {
		// Find the edge leading from the last vertex
		let nextEdge = Edge(workVertices.last!, workVertices.last!)
		if let foundEdge = workEdges[nextEdge.p.hashValue] {
			workVertices.append(foundEdge.v1)
			workEdges.removeValue(forKey: foundEdge.p.hashValue)
		} else {
			// If there is no edge leading away, this ring has closed. Restart.
			rings.append(VertexRing(vertices: workVertices))
			if let restartEdge = workEdges.first?.value {
				workVertices = [restartEdge.p]
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
