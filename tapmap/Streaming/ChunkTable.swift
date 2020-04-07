//
//  ChunkTable.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-01-25.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

struct WorldHeader {
	let treeOffset: Int
	let treeSize: Int
	let worldOffset: Int
	let worldSize: Int
	let tableOffset: Int
	let tableSize: Int
	let dataOffset: Int
	let dataSize: Int
}

class ChunkTable: Codable {
	enum CodingKeys: CodingKey {
		case lodCount
		case chunkMap
	}
	var cursor: Int = 0
	var lodCount: Int
	var chunkMap: [String : Range<Int>] = [:]
	var chunkData: Data = Data()
	
	init(withLodCount lods: Int) {
		lodCount = lods
	}
	
	func addChunk<T:Encodable>(forKey key: String, chunk: T) throws {
		let encodedChunk = try PropertyListEncoder().encode(chunk)
		let chunkRange = cursor..<(cursor + encodedChunk.count)
		chunkMap[key] = chunkRange
		
		chunkData.append(encodedChunk)
		
		cursor += chunkRange.count
	}
	
	func pullChunk<T:Decodable>(_ key: String) throws -> T {
		guard let chunkRange = chunkMap[key] else {
			print("No chunk found for \"\(key)\"")
			exit(1)
		}
		let chunkBytes = chunkData.subdata(in: chunkRange)
		return try PropertyListDecoder().decode(T.self, from: chunkBytes)
	}
}
