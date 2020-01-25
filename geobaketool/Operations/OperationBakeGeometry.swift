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
		report(0.1, "Serializing baked data...", false)
		
		var fileData = Data()
		do {
			let treeData = try PropertyListEncoder().encode(worldTree)
			let worldData = try PropertyListEncoder().encode(bakedWorld)
			let meshData = try PropertyListEncoder().encode(tessellations)
			let fileHeader = buildHeader(treeSize: treeData.count,
																	 worldSize: worldData.count,
																	 tableSize: meshData.count,
																	 dataSize: tessellations.chunkData.count)
			let headerData = withUnsafePointer(to: fileHeader) { (headerBytes) in
				return Data(bytes: headerBytes, count: MemoryLayout<WorldHeader>.size)
			}

			fileData.append(headerData)
			fileData.append(treeData)
			fileData.append(worldData)
			fileData.append(meshData)
			fileData.append(tessellations.chunkData)
		} catch (let error) {
			print("Serialisation failed: \(error.localizedDescription)")
		}
		report(0.7, "Writing world to \(saveUrl.lastPathComponent)...", false)
		
		do {
			try fileData.write(to: saveUrl, options: .atomicWrite)
			let fileSize = Int64(fileData.count)
			print("GeoWorld baked to \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
		} catch {
			print("Saving failed")
		}
	
		report(1.0, "Done.", true)
	}
	
	func buildHeader(treeSize: Int, worldSize: Int, tableSize: Int, dataSize: Int) -> WorldHeader {
		let treeOffset = MemoryLayout<WorldHeader>.size
		let worldOffset = treeOffset + treeSize
		let tableOffset = worldOffset + worldSize
		let dataOffset = tableOffset + tableSize
		
		return WorldHeader( treeOffset: treeOffset, treeSize: treeSize,
												worldOffset: worldOffset, worldSize: worldSize,
												tableOffset: tableOffset, tableSize: tableSize,
												dataOffset: dataOffset, dataSize: dataSize)
	}
	
	func buildWorld(from toolWorld: Set<ToolGeoFeature>) -> GeoWorld {
		var worldResult = Set<GeoContinent>()
		
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
				}
				
				let geoCountry = GeoCountry(name: country.name,
																		children: regionResult,
																		places: country.places ?? [],
																		contours: country.polygons.map { $0.exteriorRing },
																		parentHash: continent.hashValue,
																		aabb: countryTessellation.aabb)
				countryResult.insert(geoCountry)
			}
			
			let geoContinent = GeoContinent(name: continent.name,
																			children: countryResult,
																			places: continent.places ?? [],
																			contours: continent.polygons.map { $0.exteriorRing },
																			parentHash: 0,
																			aabb: continentTessellation.aabb)
			worldResult.insert(geoContinent)
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
	
	func buildTessellationTable(from toolWorld: Set<ToolGeoFeature>) -> ChunkTable {
		var continentTessellations: [(String, GeoTessellation)] = []
		var countryTessellations: [(String, GeoTessellation)] = []
		var regionTessellations: [(String, GeoTessellation)] = []
		
		// Serialize the tree into a list so continents come before countries come before regions.
		// This will improve cache/VM locality when pulling chunks from the baked file.
		
		continentTessellations.append(contentsOf: toolWorld.map { ($0.serializationKey, $0.tessellation!) })
		for continent in toolWorld {
			let countries = continent.children ?? []
			countryTessellations.append(contentsOf: countries.map { ($0.serializationKey, $0.tessellation!) })
			for country in continent.children ?? [] {
				let regions = country.children ?? []
				regionTessellations.append(contentsOf: regions.map { ($0.serializationKey, $0.tessellation!) })
			}
		}
		
		print("Packing tessellations...")
		print(" - \(continentTessellations.count) continents")
		print(" - \(countryTessellations.count) countries")
		print(" - \(regionTessellations.count) regions")
		
		let chunkTable = ChunkTable()
		var level = ""
		do {
			level = "continent"
			for (key, tess) in continentTessellations {
				try chunkTable.addChunk(forKey: key, chunk: tess)
			}
			
			level = "country"
			for (key, tess) in countryTessellations {
				try chunkTable.addChunk(forKey: key, chunk: tess)
			}
			
			level = "region"
			for (key, tess) in regionTessellations {
				try chunkTable.addChunk(forKey: key, chunk: tess)
			}
		} catch (let error) {
			print("Failed to encode \(level) geometry: \(error.localizedDescription)")
		}
		
		print("Built chunk table of \(ByteCountFormatter.string(fromByteCount: Int64(chunkTable.cursor), countStyle: .file))")
		
		return chunkTable
	}
}
