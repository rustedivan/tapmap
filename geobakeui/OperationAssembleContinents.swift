//
//  OperationCollectBorders.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-01-25.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

class OperationAssembleContinents : Operation {
	let countries : GeoFeatureCollection
	var continents : GeoFeatureCollection?
	let report : ProgressReport
	
	init(countries countriesOfContinent: GeoFeatureCollection,
			 reporter: @escaping ProgressReport) {
		countries = countriesOfContinent
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		print("Assembling continents")
		var continentCountries = [String : Set<GeoFeature>]()
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
		var continentFeatures = Set<GeoFeature>()
		for countryList in continentCountries {
			let contourRings = countryList.value.flatMap { $0.polygons.map { $0.exteriorRing } }
			
			let continentRings = buildContourOf(rings: contourRings, report: report, countryList.key)
			print("Collected \(contourRings.count) country rings into \(continentRings.count) continent rings.")
			let geometry = continentRings.map { GeoPolygon(exteriorRing: $0, interiorRings: []) }
			let continent = GeoFeature(level: .Continent,
																 polygons: geometry,
																 stringProperties: ["name" : countryList.key],
																 valueProperties: [:])
			continentFeatures.insert(continent)
		}
		
		continents = GeoFeatureCollection(features: continentFeatures)
		
		report(1.0, "Done.", true)
	}
}


func countEdgeCardinalities(rings: [GeoPolygonRing]) -> [Edge : Int] {
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

func buildContiguousEdgeRings(edges: [Edge], report: ProgressReport, _ reportName: String = "") -> [GeoPolygonRing] {
	var rings: [GeoPolygonRing] = []
	var workVertices: [Vertex] = []
	
	var kdTree : KDNode<Edge> = .Empty
	for e in edges {
		kdTree = kdInsert(v: e, n: kdTree)
	}
	
	// Select the starting vertex
	workVertices.append(edges.first!.v0)
	
	let numEdges = edges.count
	var nextIndex: Array<Edge>.Index = edges.startIndex
	while (!edges.isEmpty) {
		// Find the edge leading from the last vertex, assuming that it is the next index.
		// If it isn't, do a linear search for the matching edge
		if edges[nextIndex].v0 != workVertices.last {
			if let scannedIndex = edges.firstIndex(where: { $0.v0 == workVertices.last }) {
				nextIndex = scannedIndex
			} else {
				// If there is no edge leading away, this ring has closed. Restart.
				rings.append(GeoPolygonRing(vertices: workVertices))
				nextIndex = edges.startIndex
				if let e0 = edges.first {
					workVertices = [e0.v0]
				}
				
				report(1.0 - (Double(edges.count) / Double(numEdges)), "\(reportName) (\(numEdges - edges.count)/\(numEdges)", false)
				continue
			}
		}
		
		let nextEdge = edges[nextIndex]
		workVertices.append(nextEdge.v1)
//		edges.removeAll { $0 == nextEdge }
		if nextIndex == edges.endIndex {
			nextIndex = edges.startIndex
		}
	}
	
	// Insert the last ring too
	rings.append(GeoPolygonRing(vertices: workVertices))
	report(1.0, "\(reportName) (\(rings.count) rings)", true)
	
	return rings
}

func buildContourOf(rings: [GeoPolygonRing], report: ProgressReport, _ reportName: String = "") -> [GeoPolygonRing] {
	let edgeCardinalities = countEdgeCardinalities(rings: rings)
	let contourEdges = edgeCardinalities
		.filter{ $0.1 == 1 }
		.map { $0.0 }
	
	print("Plucked \(contourEdges.count) from edge pool of \(edgeCardinalities.count)")
	
	return buildContiguousEdgeRings(edges: contourEdges, report: report, reportName)
}
