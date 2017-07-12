//
//  AppUtils.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-06-27.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry

// NOTE: Will be obsoleted by Swift 4

// Inspired by Ruyichi Saito (https://medium.com/@ryuichi/swift-struct-nscoding-107fc2d6ba5e)
protocol Encodable {
	var encoded : Decodable? { get }
}

protocol Decodable {
	var decoded : Encodable? { get }
}

extension Sequence where Iterator.Element: Encodable {
	var encoded: [Decodable] {
		return flatMap { $0.encoded }
	}
}
extension Sequence where Iterator.Element: Decodable {
	var decoded: [Encodable] {
		return flatMap { $0.decoded }
	}
}

// MARK: Serialising GeoWorld

extension GeoWorld {
	class Coding : NSObject, NSCoding {
		let world: GeoWorld?
		
		init(_ world: GeoWorld) {
			self.world = world
			super.init()
		}
		
		required init?(coder aDecoder: NSCoder) {
			guard let continents = aDecoder.decodeObject(forKey: "continents") as? [GeoContinent.Coding] else { return nil	}
			
			self.world = GeoWorld(continents: continents.decoded as! [GeoContinent])
			super.init()
		}
		
		func encode(with aCoder: NSCoder) {
			guard let world = world else { return }
			aCoder.encode(world.continents.encoded, forKey: "continents")
		}
	}
}

extension GeoWorld : Encodable {
	var encoded : Decodable? {
		return GeoWorld.Coding(self)
	}
}

extension GeoWorld.Coding : Decodable {
	var decoded : Encodable? {
		return world
	}
}

// MARK: Serialising GeoContinent

extension GeoContinent {
	class Coding : NSObject, NSCoding {
		let continent: GeoContinent?
		
		init(_ continent: GeoContinent) {
			self.continent = continent
			super.init()
		}
		
		required init?(coder aDecoder: NSCoder) {
			guard let name = aDecoder.decodeObject(forKey: "name") as? String else { return nil }
			guard let vertices = aDecoder.decodeObject(forKey: "border-vertices") as? [Vertex.Coding] else { return nil	}
			guard let regions = aDecoder.decodeObject(forKey: "regions") as? [GeoRegion.Coding] else { return nil	}
			
			self.continent = GeoContinent(name: name,
																		borderVertices: vertices.decoded as! [Vertex],
																		regions: regions.decoded as! [GeoRegion])
			super.init()
		}
		
		func encode(with aCoder: NSCoder) {
			guard let continent = continent else { return }
			aCoder.encode(continent.name, forKey: "name")
			aCoder.encode(continent.borderVertices.encoded, forKey: "border-vertices")
			aCoder.encode(continent.regions.encoded, forKey: "regions")
		}
	}
}

extension GeoContinent : Encodable {
	var encoded : Decodable? {
		return GeoContinent.Coding(self)
	}
}

extension GeoContinent.Coding : Decodable {
	var decoded : Encodable? {
		return continent
	}
}

// MARK: Serialising GeoRegion
extension GeoRegion {
	class Coding : NSObject, NSCoding {
		let region: GeoRegion?
		
		init(_ region: GeoRegion) {
			self.region = region
			super.init()
		}
		
		required init?(coder aDecoder: NSCoder) {
			guard let name = aDecoder.decodeObject(forKey: "name") as? String else { return nil }
			guard let features = aDecoder.decodeObject(forKey: "features") as? [GeoFeature.Coding] else { return nil	}
			guard let tessellation = aDecoder.decodeObject(forKey: "tessellation") as? GeoTessellation.Coding else { return nil	}
			
			self.region = GeoRegion(name: name,
			                        color: GeoColors.randomColor(),
			                        features: features.decoded as! [GeoFeature],
			                        tessellation: tessellation.decoded as? GeoTessellation)
			super.init()
		}
		
		func encode(with aCoder: NSCoder) {
			guard let region = region else { return }
			aCoder.encode(region.name, forKey: "name")
			aCoder.encode(region.features.encoded, forKey: "features")
			guard let tessellation = region.tessellation?.encoded else {
				print("No tessellation for \(region.name)")
				return
			}
			aCoder.encode(tessellation, forKey: "tessellation")
		}
	}
}

extension GeoRegion : Encodable {
	var encoded : Decodable? {
		return GeoRegion.Coding(self)
	}
}

extension GeoRegion.Coding : Decodable {
	var decoded : Encodable? {
		return region
	}
}

// MARK: Serialising GeoFeature
extension GeoFeature {
	class Coding : NSObject, NSCoding {
		let feature: GeoFeature?
		
		init(_ feature: GeoFeature) {
			self.feature = feature
			super.init()
		}
		
		required init?(coder aDecoder: NSCoder) {
			let start = UInt32(aDecoder.decodeInt32(forKey: "range-start"))
			let count = UInt32(aDecoder.decodeInt32(forKey: "range-count"))
			
			let range = VertexRange(start: start, count: count)
			self.feature = GeoFeature(vertexRange: range)
			super.init()
		}
		
		func encode(with aCoder: NSCoder) {
			guard let feature = feature else { return }
			aCoder.encodeCInt(Int32(feature.vertexRange.start), forKey: "range-start")
			aCoder.encodeCInt(Int32(feature.vertexRange.count), forKey: "range-count")
		}
	}
}

extension GeoFeature : Encodable {
	var encoded : Decodable? {
		return GeoFeature.Coding(self)
	}
}

extension GeoFeature.Coding : Decodable {
	var decoded : Encodable? {
		return feature
	}
}

// MARK: Serialising GeoTessellation

extension GeoTessellation {
	class Coding : NSObject, NSCoding {
		let tessellation: GeoTessellation?
		
		init(_ tessellation: GeoTessellation) {
			self.tessellation = tessellation
			super.init()
		}
		
		required init?(coder aDecoder: NSCoder) {
			guard let vertices = aDecoder.decodeObject(forKey: "vertices") as? [Vertex.Coding] else { return nil }
			guard let indices = aDecoder.decodeObject(forKey: "indices") as? [UInt32] else { return nil }

#if os(iOS)
			let aabbRect = aDecoder.decodeCGRect(forKey: "aabb")
#else
			let aabbRect = aDecoder.decodeRect(forKey: "aabb")
#endif
			let aabb = Aabb(loX: Float(aabbRect.minX), loY: Float(aabbRect.minY), hiX: Float(aabbRect.maxX), hiY: Float(aabbRect.maxY))
			self.tessellation = GeoTessellation(vertices: vertices.decoded as! [Vertex], indices: indices, aabb: aabb)
			super.init()
		}
		
		func encode(with aCoder: NSCoder) {
			guard let tessellation = tessellation else { return }
			
			aCoder.encode(tessellation.vertices.encoded, forKey: "vertices")
			aCoder.encode(tessellation.indices, forKey: "indices")
			let aabbRect = CGRect(x: CGFloat(tessellation.aabb.minX),
			                      y: CGFloat(tessellation.aabb.minY),
			                      width: CGFloat(tessellation.aabb.maxX - tessellation.aabb.minX),
			                      height: CGFloat(tessellation.aabb.maxY - tessellation.aabb.minY))
			aCoder.encode(aabbRect, forKey: "aabb")
		}
	}
}

extension GeoTessellation : Encodable {
	var encoded : Decodable? {
		return GeoTessellation.Coding(self)
	}
}

extension GeoTessellation.Coding : Decodable {
	var decoded : Encodable? {
		return tessellation
	}
}


// MARK: Serialising Vertex
extension Vertex {
	class Coding : NSObject, NSCoding {
		let vertex: Vertex?
		
		init(_ vertex: Vertex) {
			self.vertex = vertex
			super.init()
		}
		
		required init?(coder aDecoder: NSCoder) {
#if os(iOS)
			let p = aDecoder.decodeCGPoint(forKey: "point")
#else
			let p = aDecoder.decodePoint(forKey: "point")
#endif
			
			self.vertex = Vertex(v: (Float(p.x), Float(p.y)))
			super.init()
		}
		
		func encode(with aCoder: NSCoder) {
			guard let vertex = vertex else { return }
			aCoder.encode(CGPoint(x: CGFloat(vertex.v.0), y: CGFloat(vertex.v.1)), forKey: "point")
		}
	}
}

extension Vertex : Encodable {
	var encoded : Decodable? {
		return Vertex.Coding(self)
	}
}

extension Vertex.Coding : Decodable {
	var decoded : Encodable? {
		return vertex
	}
}
