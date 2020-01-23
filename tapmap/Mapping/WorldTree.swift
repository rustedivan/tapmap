struct RegionBounds: Hashable {
	let regionHash: Int
	let bounds: Aabb
	func hash(into hasher: inout Hasher) {
		hasher.combine(regionHash)
	}
}

typealias WorldTree = QuadTree<RegionBounds>
