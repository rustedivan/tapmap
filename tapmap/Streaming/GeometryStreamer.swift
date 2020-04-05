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
	var wantedLodSetting: Int = 0
	var actualLodLevel: Int = 0
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
	
	func renderPrimitive(for streamHash: RegionHash, queueIfMissing: Bool = true) -> ArrayedRenderPrimitive? {
		let loddedStreamHash = regionHashLodKey(streamHash, atLod: actualLodLevel)
		if let primitive = primitiveCache[loddedStreamHash] {
			return primitive
		} else if (queueIfMissing) {
			// Only stream primitives that are actually opened
			if let region = AppDelegate.sharedUserState.availableRegions[streamHash] {
				streamPrimitive(for: region.geographyId)
			} else if let country = AppDelegate.sharedUserState.availableCountries[streamHash] {
				streamPrimitive(for: country.geographyId)
			} else if let continent = AppDelegate.sharedUserState.availableContinents[streamHash] {
				streamPrimitive(for: continent.geographyId)
			}
		}
		return nil
	}
	
	func evictPrimitive(for streamHash: RegionHash) {
		for lod in 0 ..< chunkTable.lodCount {
			let loddedStreamHash = regionHashLodKey(streamHash, atLod: lod)
			primitiveCache.removeValue(forKey: loddedStreamHash)
			geometryCache.removeValue(forKey: loddedStreamHash)
		}
	}
	
	func tessellation(for streamHash: RegionHash) -> GeoTessellation? {
		let key = regionHashLodKey(streamHash, atLod: actualLodLevel)
		return geometryCache[key]
	}
	
	func streamPrimitive(for regionId: RegionId) {
		let chunkName = chunkLodName(regionId, atLod: wantedLodSetting)
		let runtimeLodKey = regionHashLodKey(regionId.hashed, atLod: wantedLodSetting)
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
	
	func zoomedTo(_ zoom: Float) {
		switch zoom {
		case 0..<4.0: wantedLodSetting = 2
		case 4.0..<8.0: wantedLodSetting = 1
		default: wantedLodSetting = 0
		}
		
		actualLodLevel = wantedLodSetting
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
