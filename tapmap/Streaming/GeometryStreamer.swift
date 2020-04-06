//
//  GeometryStreamer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-01-25.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

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
	let streamQueue: OperationQueue
	var wantedLodLevel: Int
	var actualLodLevel: Int = 10
	var lodCacheMiss: Bool = true
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
		
		streamQueue = OperationQueue()
		streamQueue.name = "Geometry streaming"
		streamQueue.qualityOfService = .userInitiated
		streamQueue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
		print("  - empty streaming op-queue setup, max \(streamQueue.maxConcurrentOperationCount) concurrent loads")
		
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
			lodCacheMiss = lodCacheMiss || streamMissingPrimitive(for: regionHash)
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
	
	func tessellation(for regionHash: RegionHash) -> GeoTessellation? {
		let key = regionHashLodKey(regionHash, atLod: actualLodLevel)
		return geometryCache[key]
	}
	
	func streamPrimitive(for regionId: RegionId) {
		let chunkName = chunkLodName(regionId, atLod: wantedLodLevel)
		let runtimeLodKey = regionHashLodKey(regionId.hashed, atLod: wantedLodLevel)
		if pendingChunks.contains(runtimeLodKey) {
			return
		}
		
		pendingChunks.insert(runtimeLodKey)
		let streamOp = BlockOperation {
			if let tessellation = self.loadGeometry(chunkName) {
				OperationQueue.main.addOperation {
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
		streamQueue.addOperation(streamOp)
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
	func updateLodLevel() -> Bool {
		if actualLodLevel != wantedLodLevel {
			if !lodCacheMiss {
				actualLodLevel = wantedLodLevel
				return true
			}
		}
		lodCacheMiss = false
		return false
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
