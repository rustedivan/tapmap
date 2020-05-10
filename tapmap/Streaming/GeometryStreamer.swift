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
	
	struct GeometryEntry {
		let primitive: IndexedRenderPrimitive<Vertex>
		let tessellation: GeoTessellation
	}
	
	var metalDevice: MTLDevice?
	
	let fileData: Data	// fileData is memory-mapped so no need to attach a FileHandle here
	let fileHeader: WorldHeader
	let chunkTable: ChunkTable
	let streamQueue: DispatchQueue
	
	var wantedLodLevel: Int
	var actualLodLevel: Int = 10
	var lodCacheMiss: Bool = true
	var frameChunkRequests: [RegionId] = []
	var pendingChunks: Set<ChunkRequest> = []
	var geometryCache: [Int : GeometryEntry] = [:]
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
	
	func renderPrimitive(for regionHash: RegionHash) -> IndexedRenderPrimitive<Vertex>? {
		if primitiveHasWantedLod(for: regionHash) == false {
			let needsNewChunk = streamMissingPrimitive(for: regionHash)
			lodCacheMiss = needsNewChunk || lodCacheMiss
		}
		
		let actualRegionHash = regionHashLodKey(regionHash, atLod: actualLodLevel)
		return geometryCache[actualRegionHash]?.primitive
	}
	
	func streamMissingPrimitive(for regionHash: RegionHash) -> Bool {
		// Only stream primitives that are actually opened
		guard let regionId = regionIdLookup[regionHash] else {
			print("RegionId lookup failed for hash \(regionHash)")
			return false
		}
		streamPrimitive(for: regionId)
		return true
	}
	
	func evictPrimitive(for regionHash: RegionHash) {
		for lod in 0 ..< chunkTable.lodCount {
			let loddedRegionHash = regionHashLodKey(regionHash, atLod: lod)
			geometryCache.removeValue(forKey: loddedRegionHash)
		}
	}
	
	func tessellation(for regionHash: RegionHash, atLod lod: Int, streamIfMissing: Bool = false) -> GeoTessellation? {
		let key = regionHashLodKey(regionHash, atLod: lod)
		if let found = geometryCache[key] {
			return found.tessellation
		} else if streamIfMissing {
			_ = streamMissingPrimitive(for: regionHash)
		}
		return nil
	}
	
	func streamPrimitive(for regionId: RegionId) {
		let runtimeLodKey = regionHashLodKey(regionId.hashed, atLod: wantedLodLevel)
		if pendingChunks.contains(ChunkRequest(runtimeLodKey)) {
			return
		}
		
		frameChunkRequests.append(regionId)
	}
	
	func updateStreaming() {
		guard let device = self.metalDevice else {
			print("Cannot stream geometry before Metal setup")
			return
		}
		
		for regionId in frameChunkRequests {
			let chunkName = chunkLodName(regionId, atLod: wantedLodLevel)
			let runtimeLodKey = regionHashLodKey(regionId.hashed, atLod: wantedLodLevel)
			pendingChunks.insert(ChunkRequest(runtimeLodKey, name: regionId.key))
			
			streamQueue.async {
				if let tessellation = self.loadGeometry(chunkName) {
					// Create the render primitive and update book-keeping on the main thread
					DispatchQueue.main.async {
						let c = regionId.hashed.hashColor.tuple()
						let primitive = IndexedRenderPrimitive<Vertex>(vertices: tessellation.vertices, indices: tessellation.indices, device: device, color: c, ownerHash: regionId.hashed, debugName: chunkName)
						self.geometryCache[runtimeLodKey] = GeometryEntry(primitive: primitive, tessellation: tessellation)
						self.pendingChunks.remove(ChunkRequest(runtimeLodKey))
					}
				} else {
					print("No geometry chunk available for \(chunkName)")
				}
			}
		}
		
		logPendingRequests()
		logBlockingRequests()
		
		frameChunkRequests = []
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
		return geometryCache[wantedStreamHash] != nil
	}
	
	// For pulling chunks from the geometry archive
	func chunkLodName(_ regionId: RegionId, atLod lod: Int) -> String {
		return "\(regionId.key)-\(lod)"
	}
	
	// For referencing region-lod geometry at runtime
	func regionHashLodKey(_ regionHash: RegionHash, atLod lod: Int) -> RegionHash {
		return "\(regionHash)-\(lod)".hashValue
	}
}

// MARK: Introspection
extension GeometryStreamer {
	struct ChunkRequest: Hashable, Equatable {
		let chunkHash: RegionHash
		let name: String
		var frameCount: Int
		
		init(_ hash: RegionHash, name: String? = nil, frameCount: Int = 0) {
			self.chunkHash = hash
			self.frameCount = frameCount
			self.name = name ?? "unnamed request"
		}
		
		func hash(into hasher: inout Hasher) {
			hasher.combine(chunkHash)
		}
		
		static func == (lhs: Self, rhs: Self) -> Bool {
			return lhs.chunkHash == rhs.chunkHash
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
			print("Waiting for \(blockingRequests.map { $0.name }.joined(separator: ", "))")
		}
	}
}
