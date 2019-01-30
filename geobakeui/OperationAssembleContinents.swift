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
																 stringProperties: [:],
																 valueProperties: [:])
			continentFeatures.insert(continent)
		}
		
		continents = GeoFeatureCollection(features: continentFeatures)
		
		report(1.0, "Done.", true)
	}
}


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

func buildContiguousEdgeRings(edges: [Edge], report: ProgressReport, _ reportName: String = "") -> [GeoPolygonRing] {
	var rings: [GeoPolygonRing] = []
	var workVertices: [Vertex] = []
	var workEdges = Slice<[Edge]>(edges)
	
	// Select the starting vertex
	workVertices.append(workEdges.first!.v0)
	
	let numEdges = workEdges.count
	var nextIndex: Array<Edge>.Index = workEdges.startIndex
	while (!workEdges.isEmpty) {
		// Find the edge leading from the last vertex, assuming that it is the next index.
		// If it isn't, do a linear search for the matching edge
		if workEdges[nextIndex].v0 != workVertices.last {
			if let scannedIndex = workEdges.firstIndex(where: { $0.v0 == workVertices.last }) {
				nextIndex = scannedIndex
			} else {
				// If there is no edge leading away, this ring has closed. Restart.
				rings.append(GeoPolygonRing(vertices: workVertices))
				nextIndex = workEdges.startIndex
				if let e0 = workEdges.first {
					workVertices = [e0.v0]
				}
				
				report(1.0 - (Double(workEdges.count) / Double(numEdges)), "\(reportName) (\(numEdges - workEdges.count)/\(numEdges)", false)
				continue
			}
		}
		
		let nextEdge = workEdges[nextIndex]
		workVertices.append(nextEdge.v1)
		workEdges.removeAll { $0 == nextEdge }
		if nextIndex == workEdges.endIndex {
			nextIndex = workEdges.startIndex
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
