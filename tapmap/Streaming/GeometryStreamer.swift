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
	
	func renderPrimitive(for streamHash: RegionHash, queueIfMissing: Bool = true) -> ArrayedRenderPrimitive? {
		if let primitive = primitiveCache[streamHash] {
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
		primitiveCache.removeValue(forKey: streamHash)
		geometryCache.removeValue(forKey: streamHash)
	}
	
	func tessellation(for streamHash: RegionHash) -> GeoTessellation? {
		return geometryCache[streamHash]
	}
	
	func streamPrimitive(for regionId: RegionId) {
		if pendingChunks.contains(regionId.hashed) {
			return
		}
		
		pendingChunks.insert(regionId.hashed)
		let streamOp = BlockOperation {
			let startTime = DispatchTime.now()
			if let tessellation = self.streamGeometry(regionId.key) {
				OperationQueue.main.addOperation {
					let c = regionId.hashed.hashColor.tuple()
					let primitive = ArrayedRenderPrimitive(vertices: tessellation.vertices, color: c, ownerHash: regionId.hashed, debugName: regionId.key)
					self.primitiveCache[regionId.hashed] = primitive
					self.geometryCache[regionId.hashed] = tessellation
					self.pendingChunks.remove(regionId.hashed)
//					let duration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds)/1e9
//					print("Streamed \(regionId.key) (\(primitive.elementCount) vertices) after \(String(format: "%.2f", duration)) seconds")
				}
			} else {
				print("No geometry chunk available for \(regionId.key)")
			}
		}
		streamQueue.addOperation(streamOp)
	}
	
	private func streamGeometry(_ name: String) -> GeoTessellation? {
		do {
			return try chunkTable.pullChunk(name)
		} catch (let error) {
			print("Could not load tessellation: \(error.localizedDescription)")
			return nil
		}
	}
}
