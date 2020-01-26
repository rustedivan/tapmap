struct RegionBounds: Codable, Hashable {
	let regionHash: RegionHash
	let bounds: Aabb
	func hash(into hasher: inout Hasher) {
		hasher.combine(regionHash)
	}
}

typealias WorldTree = QuadTree<RegionBounds>
