//
//  PoiRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
	let rankThreshold: simd_float1
	let poiBaseSize: simd_float1
}

fileprivate struct InstanceUniforms {
	var progress: simd_float1
}

struct PoiPlane: Hashable {
	let primitive: IndexedRenderPrimitive<ScaleVertex>
	let rank: Int
	let representsArea: Bool
	var ownerHash: Int { return primitive.ownerHash }
	let poiHashes: [Int]
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(primitive.ownerHash)
		hasher.combine(rank)
	}
	
	static func == (lhs: PoiPlane, rhs: PoiPlane) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
}

/*
	The POI renderer is oriented around sets of "POI planes". A POI plane is a render primitive that
	holds a collection of POIs that will follow the same culling/fading events. For instance,
	all the capitals in Europe are on the same POI plane, all the cities in Bavaria are on the same plane,
	and all the towns in Jalisco are on the same plane - because they will be made visible together, and
	will fade in and out at the same time.

	Each POI plane knows if it contains point or area markers, as area markers (country, region, park...)
	are only visible at a zoom _range_, while point markers are visible above a zoom _threshold. This logic
	sits in cullPlaneToZoomRange()

	The PoiRenderer also provides the activePoiHashes comp-prop to export the list of exactly which POIs
	are rendered. This list is fed to the LabelView that needs the detailed information.
*/

class PoiRenderer {
	static let kMaxVisibleInstances = 256
	enum Visibility {
		static let FadeInDuration = 0.4
		static let FadeOutDuration = 0.2
		case fadeIn(startTime: Date)
		case fadeOut(startTime: Date)
		case visible
		
		func alpha() -> Float {
			switch self {
			case .fadeIn(let startTime):
				let progress = Date().timeIntervalSince(startTime) / PoiRenderer.Visibility.FadeInDuration
				return Float(min(progress, 1.0))
			case .fadeOut(let startTime):
				let progress = Date().timeIntervalSince(startTime) / PoiRenderer.Visibility.FadeOutDuration
				return Float(max(1.0 - progress, 0.0))
			case .visible: return 1.0
			}
		}
	}
	var poiPlanePrimitives : [PoiPlane]
	var poiVisibility: [Int : Visibility] = [:]
	var renderList: [PoiPlane] = []
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]
	
	var rankThreshold: Float = -1.0
	var poiBaseSize: Float = 0.0
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int,
				withVisibleContinents continents: GeoContinentMap,
				countries: GeoCountryMap,
				provinces: GeoProvinceMap) {
		
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = shaderLib.makeFunction(name: "poiVertex")
		pipelineDescriptor.fragmentFunction = shaderLib.makeFunction(name: "poiFragment")
		pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
		pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		pipelineDescriptor.vertexBuffers[0].mutability = .immutable
		pipelineDescriptor.vertexBuffers[1].mutability = .immutable
		pipelineDescriptor.vertexBuffers[2].mutability = .immutable
		
		do {
			try pipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
			self.device = device
			self.instanceUniforms = (0..<bufferCount).map { _ in
				return device.makeBuffer(length: PoiRenderer.kMaxVisibleInstances * MemoryLayout<InstanceUniforms>.stride, options: .storageModeShared)!
			}
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		let visibleContinentPoiPlanes = continents.values.flatMap { sortPlacesIntoPoiPlanes($0.places, in: $0, inDevice: device) }
		let visibleCountryPoiPlanes = countries.values.flatMap { sortPlacesIntoPoiPlanes($0.places, in: $0, inDevice: device) }
		let visibleProvincePoiPlanes = provinces.values.flatMap { sortPlacesIntoPoiPlanes($0.places, in: $0, inDevice: device) }
		
		poiPlanePrimitives = visibleContinentPoiPlanes + visibleCountryPoiPlanes + visibleProvincePoiPlanes
	}
	
	var activePoiHashes: Set<Int> {
		let visiblePoiPlanes = poiPlanePrimitives.filter { self.poiVisibility[$0.hashValue] != nil }
		return Set(visiblePoiPlanes.flatMap { $0.poiHashes })
	}
	
	func updatePrimitives<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>) where T.SubType : GeoPlaceContainer {
		let removedRegionsHash = node.geographyId.hashed
		poiPlanePrimitives = poiPlanePrimitives.filter { $0.ownerHash != removedRegionsHash }
		
		let subregionPrimitives = subRegions.flatMap { buildPoiPlanes(of: $0) }
		poiPlanePrimitives.append(contentsOf: subregionPrimitives)
		
		for newRegion in subregionPrimitives {
			if Float(newRegion.rank) <= rankThreshold {
				poiVisibility.updateValue(.visible, forKey: newRegion.hashValue)
			}
		}
	}
	
	func buildPoiPlanes<T:GeoPlaceContainer & GeoIdentifiable>(of region: T) -> [PoiPlane] {
		return sortPlacesIntoPoiPlanes(region.places, in: region, inDevice: device);
	}
	
	func prepareFrame(visibleSet: Set<RegionHash>, bufferIndex: Int) {
		let now = Date()
		for (key, p) in poiVisibility {
			switch(p) {
			case .fadeIn(let startTime):
				if startTime.addingTimeInterval(1.0) < now {
					poiVisibility.updateValue(.visible, forKey: key)
				}
			case .fadeOut(let startTime):
				if startTime.addingTimeInterval(1.0) < now {
					poiVisibility.removeValue(forKey: key)
				}
				break
			default: break
			}
		}
		
		renderList = poiPlanePrimitives.filter({ visibleSet.contains($0.ownerHash) })
																			.filter({ poiVisibility[$0.hashValue] != nil })
		var fades = Array<InstanceUniforms>()
		fades.reserveCapacity(renderList.count)
		for plane in renderList {
			let u = InstanceUniforms(progress: poiVisibility[plane.hashValue]!.alpha())
			fades.append(u)
		}
		instanceUniforms[bufferIndex].contents().copyMemory(from: fades,
																												byteCount: MemoryLayout<InstanceUniforms>.stride * fades.count)
	}
	
	func updateZoomThreshold(viewZoom: Float) {
		if rankThreshold == viewZoom {
			return
		}
		
		let oldRankThreshold = rankThreshold
		rankThreshold = viewZoom
		
		let previousPois = Set(poiPlanePrimitives.filter { cullPlaneToZoomRange(plane: $0, zoom: oldRankThreshold) })
		let visiblePois = Set(poiPlanePrimitives.filter { cullPlaneToZoomRange(plane: $0, zoom: rankThreshold) })

		let poisToHide = previousPois.subtracting(visiblePois)	// Culled this frame
		let poisToShow = visiblePois.subtracting(previousPois) // Shown this frame
		
		for p in poisToHide {
			poiVisibility.updateValue(.fadeOut(startTime: Date()), forKey: p.hashValue)
		}
		
		for p in poisToShow {
			poiVisibility.updateValue(.fadeIn(startTime: Date()), forKey: p.hashValue)
		}
	}
	
	func cullPlaneToZoomRange(plane: PoiPlane, zoom: Float) -> Bool {
		var minZoom: Float = 0.0, maxZoom: Float = 1000.0
		switch (plane.rank, plane.representsArea) {
		case (0...1, false): 		minZoom = 2.0			// Captials; not visible at outmost zoom
		case (2, false): 				minZoom = 5.0			// Cities
		case (3, false): 				minZoom = 10.0
		case (4, false):				minZoom = 12.0
		case (5, false): 				minZoom = 14.0
		case (6, false): 				minZoom = 16.0
		case (7, false):				minZoom = 40.0		// Towns
		case (8, false): 				minZoom = 60.0
		case (0, true):					maxZoom = 7.0
		case (1, true):					minZoom = 3.0;  maxZoom = 30.0
		case (_, true): 				minZoom = 15.0; maxZoom = 40.0
		case (_, _): 						minZoom = 1000.0
		}
		
		return minZoom <= zoom && zoom <= maxZoom
	}
	
	func updateStyle(zoomLevel: Float) {
		let poiScreenSize: Float = 2.0
		poiBaseSize = poiScreenSize / (zoomLevel)
		poiBaseSize += min(zoomLevel * 0.01, 0.1)	// Boost POI sizes a bit when zooming in
	}
	
	func renderWorld(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render POI plane")
		encoder.setRenderPipelineState(pipeline)
		
		var frameUniforms = FrameUniforms(mvpMatrix: projection,
																			 rankThreshold: rankThreshold,
																			 poiBaseSize: poiBaseSize)
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setVertexBuffer(instanceUniforms[bufferIndex], offset: 0, index: 2)
		
		var instanceCursor = 0
		for poiPlane in renderList {
			encoder.setVertexBufferOffset(instanceCursor, index: 2)
			render(primitive: poiPlane.primitive, into: encoder)
			
			instanceCursor += MemoryLayout<InstanceUniforms>.stride
		}
		
		encoder.popDebugGroup()
	}
}

// MARK: Generating POI planes
func bucketPlaceMarkers(places: Set<GeoPlace>) -> [Int: Set<GeoPlace>] {
	var bins: [Int: Set<GeoPlace>] = [:]
	for place in places {
		if bins[place.rank] != nil {
			bins[place.rank]!.insert(place)
		} else {
			bins[place.rank] = Set<GeoPlace>([place])
		}
	}
	return bins
}

func buildPlaceMarkers(places: Set<GeoPlace>) -> ([ScaleVertex], [UInt16]) {
	let vertices = places.reduce([]) { (accumulator: [ScaleVertex], place: GeoPlace) in
		let size = 1.0 / Float(place.rank > 0 ? place.rank : 1)
		let v0 = ScaleVertex(0.0, 0.0, normalX: -size, normalY: -size)
		let v1 = ScaleVertex(0.0, 0.0, normalX: size, normalY: -size)
		let v2 = ScaleVertex(0.0, 0.0, normalX: size, normalY: size)
		let v3 = ScaleVertex(0.0, 0.0, normalX: -size, normalY: size)
		let verts = [v0, v1, v2, v3].map {
			ScaleVertex(place.location.x, place.location.y, normalX: $0.normalX, normalY: $0.normalY)
		}
		return accumulator + verts
	}
	
	let quadRange = 0..<UInt16(places.count)
	let indices = quadRange.reduce([]) { (accumulator: [UInt16], quadIndex: UInt16) in
		let quadIndices: [UInt16] = [0, 2, 1, 0, 3, 2]	// Build two triangles from the four quad vertices
		let vertexOffset = quadIndex * 4
		let offsetIndices = quadIndices.map { $0 + vertexOffset }
		return accumulator + offsetIndices
	}
	
	return (vertices, indices)
}

func sortPlacesIntoPoiPlanes<T: GeoIdentifiable>(_ places: Set<GeoPlace>, in container: T, inDevice device: MTLDevice) -> [PoiPlane] {
	let placeMarkers = places.filter { $0.kind != .Region }
	let areaMarkers = places.filter { $0.kind == .Region }
	let rankedPlaces = bucketPlaceMarkers(places: placeMarkers)
	let rankedAreas = bucketPlaceMarkers(places: areaMarkers )
	
	let generatePlacePlanes = makePoiPlaneFactory(forArea: false, in: container, inDevice: device)
	let generateAreaPlanes = makePoiPlaneFactory(forArea: true, in: container, inDevice: device)
	
	let placePlanes = rankedPlaces.map(generatePlacePlanes)
	let areaPlanes = rankedAreas.map(generateAreaPlanes)
	
	return areaPlanes + placePlanes
}

typealias PoiFactory = (Int, Set<GeoPlace>) -> PoiPlane
func makePoiPlaneFactory<T:GeoIdentifiable>(forArea: Bool, in container: T, inDevice device: MTLDevice) -> PoiFactory {
	return { (rank: Int, pois: Set<GeoPlace>) -> PoiPlane in
		let (vertices, indices) = buildPlaceMarkers(places: pois)
		let primitive = IndexedRenderPrimitive<ScaleVertex>(vertices: vertices,
																												indices: indices,
																												device: device,
																												color: rank.hashColor.tuple(),
																												ownerHash: container.geographyId.hashed,	// The hash of the owning region
																												debugName: "\(container.name) - \(forArea ? "area" : "poi") plane @ \(rank)")
		let hashes = pois.map { $0.hashValue }
		return PoiPlane(primitive: primitive, rank: rank, representsArea: forArea, poiHashes: hashes)
	}
}
