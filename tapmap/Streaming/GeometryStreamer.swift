//
//  GeometryStreamer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-01-25.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation
import Dispatch

class GeometryStreamer {
	static private var _shared: GeometryStreamer!
	static var shared: GeometryStreamer {
		get {
			if _shared == nil {
				print("Geometry streamer has not been created yet.")
				exit(1)
			}
			return _shared
		}
	}
	
	let fileData: Data	// fileData is memory-mapped so no need to attach a FileHandle here
	let fileHeader: WorldHeader
	let chunkTable: ChunkTable
	let streamQueue: DispatchQueue
	var wantedLodLevel: Int
	var actualLodLevel: Int = 10
	var lodCacheMiss: Bool = true
	var newChunkRequests: [RegionId] = []
	var pendingChunks: Set<Int> = []
	var primitiveCache: [Int : ArrayedRenderPrimitive] = [:]
	var geometryCache: [Int : GeoTessellation] = [:]
	var streaming: Bool { get {
		return !pendingChunks.isEmpty
	}}
	
	init?(attachFile path: String) {
		let startTime = Date()
		print("Attaching geometry streamer...")
		do {
			fileData = try NSData(contentsOfFile: path, options: .mappedIfSafe) as Data
		} catch (let e) {
			print(e.localizedDescription)
			return nil
		}
		
		let headerData = fileData.subdata(in: 0..<MemoryLayout<WorldHeader>.size)
		fileHeader = headerData.withUnsafeBytes { (bytes) in
			return bytes.load(as: WorldHeader.self)
		}
		print("  - expecting \(ByteCountFormatter.string(fromByteCount: Int64(fileHeader.dataSize), countStyle: .memory)) of geometry data")
	
		let loadedTableBytes = fileData.subdata(in: fileHeader.tableOffset..<fileHeader.tableOffset + fileHeader.tableSize)
		let loadedTable = try! PropertyListDecoder().decode(ChunkTable.self, from: loadedTableBytes)
		chunkTable = loadedTable
		print("  - geometry streamer has \(chunkTable.chunkMap.count) tesselation entries")
		
		wantedLodLevel = chunkTable.lodCount - 1
		print("  - geometry streamer has \(chunkTable.lodCount) LOD levels; start at LOD\(actualLodLevel)")
		chunkTable.chunkData = fileData.subdata(in: fileHeader.dataOffset..<fileHeader.dataOffset + fileHeader.dataSize)
		print("  - chunk data attached with \(ByteCountFormatter.string(fromByteCount: Int64(chunkTable.chunkData.count), countStyle: .memory))")
		
		streamQueue = DispatchQueue(label: "Geometry streaming", qos: .userInitiated, attributes: .concurrent)
		print("  - empty streaming op-queue setup")
		
		GeometryStreamer._shared = self
		
		let duration = Date().timeIntervalSince(startTime)
		print("  - ready to stream after \(String(format: "%.2f", duration)) seconds")
	}
	
	func loadWorldTree() -> WorldTree {
		let loadedTreeBytes = fileData.subdata(in: fileHeader.treeOffset..<fileHeader.treeOffset + fileHeader.treeSize)
		let loadedTree = try! PropertyListDecoder().decode(WorldTree.self, from: loadedTreeBytes)
		return loadedTree
	}
	
	func loadGeoWorld() -> GeoWorld {
		let loadedWorldBytes = fileData.subdata(in: fileHeader.worldOffset..<fileHeader.worldOffset + fileHeader.worldSize)
		let loadedWorld = try! PropertyListDecoder().decode(GeoWorld.self, from: loadedWorldBytes)
		return loadedWorld
	}
	
	func renderPrimitive(for regionHash: RegionHash) -> ArrayedRenderPrimitive? {
		if primitiveHasWantedLod(for: regionHash) == false {
			let needsNewChunk = streamMissingPrimitive(for: regionHash)
			lodCacheMiss = needsNewChunk || lodCacheMiss
		}
		
		let actualRegionHash = regionHashLodKey(regionHash, atLod: actualLodLevel)
		let renderPrimitive = primitiveCache[actualRegionHash]
		return renderPrimitive
	}
	
	func streamMissingPrimitive(for regionHash: RegionHash) -> Bool {
		// Only stream primitives that are actually opened
		if let region = AppDelegate.sharedUserState.availableRegions[regionHash] {
			streamPrimitive(for: region.geographyId)
			return true
		} else if let country = AppDelegate.sharedUserState.availableCountries[regionHash] {
			streamPrimitive(for: country.geographyId)
			return true
		} else if let continent = AppDelegate.sharedUserState.availableContinents[regionHash] {
			streamPrimitive(for: continent.geographyId)
			return true
		}
		return false
	}
	
	func evictPrimitive(for regionHash: RegionHash) {
		for lod in 0 ..< chunkTable.lodCount {
			let loddedRegionHash = regionHashLodKey(regionHash, atLod: lod)
			primitiveCache.removeValue(forKey: loddedRegionHash)
			geometryCache.removeValue(forKey: loddedRegionHash)
		}
	}
	
	func tessellation(for regionHash: RegionHash, atLod lod: Int) -> GeoTessellation? {
		let key = regionHashLodKey(regionHash, atLod: lod)
		return geometryCache[key]
	}
	
	func streamPrimitive(for regionId: RegionId) {
		let runtimeLodKey = regionHashLodKey(regionId.hashed, atLod: wantedLodLevel)
		if pendingChunks.contains(runtimeLodKey) {
			return
		}
		
		newChunkRequests.append(regionId)
	}
	
	func updateStreaming() {
		for regionId in newChunkRequests {
			let chunkName = chunkLodName(regionId, atLod: wantedLodLevel)
			let runtimeLodKey = regionHashLodKey(regionId.hashed, atLod: wantedLodLevel)
			pendingChunks.insert(runtimeLodKey)
			
			streamQueue.async {
				if let tessellation = self.loadGeometry(chunkName) {
					// Create the render primitive and update book-keeping on the OpenGL/main thread
					DispatchQueue.main.async {
						let c = regionId.hashed.hashColor.tuple()
						let primitive = ArrayedRenderPrimitive(vertices: tessellation.vertices, color: c, ownerHash: regionId.hashed, debugName: chunkName)
						self.primitiveCache[runtimeLodKey] = primitive
						self.geometryCache[runtimeLodKey] = tessellation
						self.pendingChunks.remove(runtimeLodKey)
					}
				} else {
					print("No geometry chunk available for \(chunkName)")
				}
			}
		}
		
		newChunkRequests = []
	}
	
	private func loadGeometry(_ name: String) -> GeoTessellation? {
		do {
			return try chunkTable.pullChunk(name)
		} catch (let error) {
			print("Could not load tessellation: \(error.localizedDescription)")
			return nil
		}
	}
}

// MARK: LOD management
extension GeometryStreamer {
	func updateLodLevel() {
		if actualLodLevel != wantedLodLevel {
			if !lodCacheMiss {
				actualLodLevel = wantedLodLevel
				return
			}
		}
		lodCacheMiss = false
	}
	
	func zoomedTo(_ zoom: Float) {
		let setToLevel: Int
		switch zoom {
		case 0..<4.0: setToLevel = 2
		case 4.0..<8.0: setToLevel = 1
		default: setToLevel = 0
		}
		
		if wantedLodLevel != setToLevel {
			wantedLodLevel = setToLevel
			lodCacheMiss = true
		}
	}
	
	func primitiveHasWantedLod(for regionHash: RegionHash) -> Bool {
		let wantedStreamHash = regionHashLodKey(regionHash, atLod: wantedLodLevel)
		return primitiveCache[wantedStreamHash] != nil
	}
	
	// For pulling chunks from the geometry archive
	func chunkLodName(_ regionId: RegionId, atLod lod: Int) -> String {
		return "\(regionId.key)-\(lod)"
	}
	
	// For referencing region-lod geometry at runtime
	func regionHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> Int {
		return "\(regionHash)-\(lod)".hashValue
	}
}
