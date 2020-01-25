//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let input : Set<ToolGeoFeature>
	let saveUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	
	init(world worldToBake: Set<ToolGeoFeature>,
			 saveUrl url: URL,
	     reporter: @escaping ProgressReport,
	     errorReporter: @escaping ErrorReport) {
		input = worldToBake
		saveUrl = url
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		// Bake job should only do this conversion and save
		let bakedWorld = buildWorld(from: input)
		let tessellations = buildTessellationTable(from: input)
		let worldTree = buildTree(from: bakedWorld)
		
		print("\n")
		report(0.1, "Writing world to \(saveUrl.lastPathComponent)...", false)
		
		let encoder = PropertyListEncoder()
		
		if let encoded = try? encoder.encode(bakedWorld) {
			do {
				try encoded.write(to: saveUrl, options: .atomicWrite)
				print("GeoWorld baked to \(ByteCountFormatter().string(fromByteCount: Int64(encoded.count)))")
			} catch {
				print("Saving failed")
			}
		}
		else {
			print("Encoding failed")
		}
		report(1.0, "Done.", true)
	}
	
	func buildWorld(from toolWorld: Set<ToolGeoFeature>) -> GeoWorld {
		var worldResult = Set<GeoContinent>()
		var continentTessellations: [Int : GeoTessellation] = [:]
		var countryTessellations: [Int : GeoTessellation] = [:]
		var regionTessellations: [Int : GeoTessellation] = [:]
		
		// Build continents
		for continent in toolWorld {
			guard let continentTessellation = continent.tessellation else {
				print("\(continent.name) has no tessellation - skipping...")
				continue
			}

			// Build countries
			var countryResult = Set<GeoCountry>()
			for country in continent.children ?? [] {
				guard let countryTessellation = country.tessellation else {
					print("\(country.name) has no tessellation - skipping...")
					continue
				}
				
				// Build regions
				var regionResult = Set<GeoRegion>()
				for region in country.children ?? [] {
					guard let regionTessellation = region.tessellation else {
						print("\(region.name) has no tessellation - skipping...")
						continue
					}
					
					let geoRegion = GeoRegion(name: region.name,
																		contours: region.polygons.map { $0.exteriorRing },
																		places: region.places ?? [],
																		parentHash: country.hashValue,
																		aabb: regionTessellation.aabb)
					regionResult.insert(geoRegion)
					regionTessellations[geoRegion.hashValue] = regionTessellation
				}
				
				let geoCountry = GeoCountry(name: country.name,
																		children: regionResult,
																		places: country.places ?? [],
																		contours: country.polygons.map { $0.exteriorRing },
																		parentHash: continent.hashValue,
																		aabb: countryTessellation.aabb)
				countryResult.insert(geoCountry)
				countryTessellations[geoCountry.hashValue] = countryTessellation
			}
			
			let geoContinent = GeoContinent(name: continent.name,
																			children: countryResult,
																			places: continent.places ?? [],
																			contours: continent.polygons.map { $0.exteriorRing },
																			parentHash: 0,
																			aabb: continentTessellation.aabb)
			worldResult.insert(geoContinent)
			continentTessellations[geoContinent.hashValue] = continentTessellation
		}
		return GeoWorld(name: "Earth", children: worldResult, parentHash: 0)
	}
	
	func buildTree(from bakedWorld: GeoWorld) -> WorldTree {
		var worldQuadTree = QuadTree<RegionBounds>(minX: -180.0, minY: -90.0, maxX: 181.0, maxY: 90.0, maxDepth: 6)
		
		for continent in bakedWorld.children {
			for country in continent.children {
				for region in country.children {
					let regionBox = RegionBounds(regionHash: region.hashValue, bounds: region.aabb)
					worldQuadTree.insert(value: regionBox, region: regionBox.bounds)
				}
				
				let countryBox = RegionBounds(regionHash: country.hashValue, bounds: country.aabb)
				worldQuadTree.insert(value: countryBox, region: countryBox.bounds)
			}
			
			let continentBox = RegionBounds(regionHash: continent.hashValue, bounds: continent.aabb)
			worldQuadTree.insert(value: continentBox, region: continentBox.bounds)
		}
		return worldQuadTree
	}
	
	func buildTessellationTable(from toolWorld: Set<ToolGeoFeature>) -> Bool {
		var continentTessellations: [(Int, GeoTessellation)] = []
		var countryTessellations: [(Int, GeoTessellation)] = []
		var regionTessellations: [(Int, GeoTessellation)] = []
		
		// Serialize the tree into a list so continents come before countries come before regions.
		// This will improve cache/VM locality when pulling chunks from the baked file.
		
		continentTessellations.append(contentsOf: toolWorld.map { ($0.runtimeHash(), $0.tessellation!) })
		for continent in toolWorld {
			let countries = continent.children ?? []
			countryTessellations.append(contentsOf: countries.map { ($0.runtimeHash(), $0.tessellation!) })
			for country in continent.children ?? [] {
				let regions = country.children ?? []
				regionTessellations.append(contentsOf: regions.map { ($0.runtimeHash(), $0.tessellation!) })
			}
		}
		
		print("Packing tessellations...")
		print(" - \(continentTessellations.count) continents")
		print(" - \(countryTessellations.count) countries")
		print(" - \(regionTessellations.count) regions")
		
		
		
		return false
	}
}
