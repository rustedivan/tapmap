//
//  GeometryStreamer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-01-25.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation
import Dispatch
import Metal

class GeometryStreamer {
	typealias StreamedPrimitive = RenderPrimitive
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
	
	var metalDevice: MTLDevice?
	
	let fileData: Data	// fileData is memory-mapped so no need to attach a FileHandle here
	let fileHeader: WorldHeader
	let chunkTable: ChunkTable
	let streamQueue: DispatchQueue	// Async stream data from archive
	
	var wantedLodLevel: Int
	var actualLodLevel: Int = 10
	var lodCacheMiss: Bool = true
	var pendingChunks: Set<ChunkRequest> = []										// Tracks outstanding stream requests
	var deliveredChunks: [(ChunkRequest, GeoTessellation, StreamedPrimitive)] = []	// Chunks that finished streaming in this frame
	var chunkLock: os_unfair_lock = os_unfair_lock()
	
	var tessellationCache: [Int : GeoTessellation] = [:]
	var primitiveCache: [Int : StreamedPrimitive] = [:]
	var regionIdLookup: [RegionHash : RegionId] = [:]	// To avoid dependency on RuntimeWorld
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
		
		streamQueue = DispatchQueue(label: "Geometry streaming", qos: .utility, attributes: .concurrent)
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
		
		// Create a lookup from RegionHash to RegionId to go to ChunkName
		let continentList = loadedWorld.children
		let countryList = continentList.flatMap { $0.children }
		let regionList = countryList.flatMap { $0.children }
		var regionHashToRegionId: [RegionHash : RegionId] = [:]
		regionHashToRegionId.merge(continentList.map { ($0.geographyId.hashed, $0.geographyId) }, uniquingKeysWith: { (lhs, rhs) in lhs})
		regionHashToRegionId.merge(countryList.map { ($0.geographyId.hashed, $0.geographyId) }, uniquingKeysWith: { (lhs, rhs) in lhs})
		regionHashToRegionId.merge(regionList.map { ($0.geographyId.hashed, $0.geographyId) }, uniquingKeysWith: { (lhs, rhs) in lhs})
		regionIdLookup = regionHashToRegionId
		return loadedWorld
	}
	
	func renderPrimitive(for regionHash: RegionHash, streamIfMissing: Bool = false) -> StreamedPrimitive? {
		let actualStreamHash = regionHashLodKey(regionHash, atLod: actualLodLevel)
		let wantedStreamHash = regionHashLodKey(regionHash, atLod: wantedLodLevel)
		
		if primitiveCache[wantedStreamHash] == nil && streamIfMissing {
			streamMissingPrimitive(for: regionHash)
			lodCacheMiss = true
		}
		return primitiveCache[actualStreamHash]
	}
	
	func tessellation(for regionHash: RegionHash, atLod lod: Int, streamIfMissing: Bool = false) -> GeoTessellation? {
		let key = regionHashLodKey(regionHash, atLod: lod)
		let found = tessellationCache[key]
		
		if found != nil {
			return found
		} else if streamIfMissing {
			streamMissingPrimitive(for: regionHash)
		}
		return nil
	}
	
	func evictPrimitive(for regionHash: RegionHash) {
		for lod in 0 ..< chunkTable.lodCount {
			let loddedRegionHash = regionHashLodKey(regionHash, atLod: lod)
			primitiveCache.removeValue(forKey: loddedRegionHash)
		}
	}
	
	private func streamMissingPrimitive(for regionHash: RegionHash) {
		guard let regionId = regionIdLookup[regionHash] else {
			print("RegionId lookup failed for hash \(regionHash)")
			return
		}
		
		if !pendingChunks.contains(ChunkRequest(regionId, atLod: wantedLodLevel)) {
			let chunkName = chunkLodName(regionId, atLod: wantedLodLevel)
			let request = ChunkRequest(regionId, atLod: wantedLodLevel)
			pendingChunks.insert(request)
			
			streamQueue.async {
				guard let tessellation = self.loadGeometry(chunkName) else {
					print("No geometry chunk available for \(chunkName)")
					return
				}
				
				let primitive = StreamedPrimitive(polygons: [tessellation.vertices],
																					indices: [tessellation.indices],
																					drawMode: .triangle,
																					device: self.metalDevice!,
																					color: Color(r: tessellation.color.r, g: tessellation.color.g, b: tessellation.color.b, a: 1.0),
																					ownerHash: regionHash,
																					debugName: "Unnamed")	// $ Embed name in tessellation
				
				// Don't allow reads while publishing finished chunk
				os_unfair_lock_lock(&self.chunkLock)
					self.deliveredChunks.append((request, tessellation, primitive))
				os_unfair_lock_unlock(&self.chunkLock)
			}
		}
	}
	
	func updateStreaming() {
		if os_unfair_lock_trylock(&chunkLock) {
			for (request, tessellation, primitive) in deliveredChunks {
				let runtimeLodKey = regionHashLodKey(request.chunkId.hashed, atLod: request.lodLevel)
				tessellationCache[runtimeLodKey] = tessellation
				primitiveCache[runtimeLodKey] = primitive
			}
			
			let finishedRequests = deliveredChunks.map { $0.0 }
			pendingChunks = pendingChunks.subtracting(finishedRequests)
			deliveredChunks = []
		
			logPendingRequests()
			logBlockingRequests()
			os_unfair_lock_unlock(&chunkLock)
		}
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
		
		wantedLodLevel = setToLevel
	}
}

// For pulling chunks from the geometry archive
fileprivate func chunkLodName(_ regionId: RegionId, atLod lod: Int) -> String {
	return "\(regionId.key)-\(lod)"
}

// For referencing region-lod geometry at runtime
fileprivate func regionHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> RegionHash {
	return "\(regionHash)-\(lod)".hashValue
}

// MARK: Introspection
extension GeometryStreamer {
	struct ChunkRequest: Hashable, Equatable {
		let chunkId: RegionId
		let lodLevel: Int
		var frameCount: Int
		
		init(_ regionId: RegionId, atLod lod: Int, frameCount: Int = 0) {
			self.chunkId = regionId
			self.lodLevel = lod
			self.frameCount = frameCount
		}
		
		func hash(into hasher: inout Hasher) {
			hasher.combine(regionHashLodKey(chunkId.hashed, atLod: lodLevel))
		}
		
		static func == (lhs: Self, rhs: Self) -> Bool {
			return regionHashLodKey(lhs.chunkId.hashed, atLod: lhs.lodLevel) == regionHashLodKey(rhs.chunkId.hashed, atLod: rhs.lodLevel)
		}
	}
	
	func logPendingRequests() {
		for var request in pendingChunks {
			request.frameCount += 1
		}
	}
	
	func logBlockingRequests() {
		let blockingRequests = pendingChunks.filter { $0.frameCount > 30 }
		if !blockingRequests.isEmpty {
			print("Waiting for \(blockingRequests.map { $0.chunkId.key }.joined(separator: ", "))")
		}
	}
}
