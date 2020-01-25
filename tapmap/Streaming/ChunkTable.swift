//
//  ChunkTable.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-01-25.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class ChunkTable: Codable {
	enum CodingKeys: CodingKey {
		case chunkMap
	}
	var cursor: Int = 0
	var chunkMap: [Int : Range<Int>] = [:]
	var chunkData: Data = Data()
	
	func addChunk<T:Encodable>(forKey key: Int, chunk: T) throws {
		let encodedChunk = try PropertyListEncoder().encode(chunk)
		let chunkRange = cursor..<(cursor + encodedChunk.count)
		chunkMap[key] = chunkRange
		
		chunkData.append(encodedChunk)
		
		cursor += chunkRange.count
	}
	
	func pullChunk<T:Decodable>(_ key: Int) throws -> T {
		guard let chunkRange = chunkMap[key] else {
			print("No chunk found for \"\(key)\"")
			exit(1)
		}
		let chunkBytes = chunkData.subdata(in: chunkRange)
		return try PropertyListDecoder().decode(T.self, from: chunkBytes)
	}
}
