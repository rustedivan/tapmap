//
//  PoiRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Metal
import MetalKit
import simd

fileprivate struct FrameUniforms {
	let mvpMatrix: simd_float4x4
	let rankThreshold: simd_float1
	let poiBaseSize: simd_float1
}

fileprivate struct InstanceUniform {
	var position: simd_float2
	var progress: simd_float1
}

struct PoiGroup: Hashable {
	let locations: [Vertex]
	let rank: Int
	let representsArea: Bool
	var ownerHash: Int
	let poiHashes: [Int]
	let debugName: String
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(ownerHash)
		hasher.combine(rank)
	}
	
	static func == (lhs: PoiGroup, rhs: PoiGroup) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
}

/*
	The POI renderer is oriented around sets of "POI groups". A POI group is a render primitive that
	holds a collection of POIs that will follow the same culling/fading events. For instance,
	all the capitals in Europe are in the same POI group, all the cities in Bavaria are in the same group,
	and all the towns in Jalisco are in the same group - because they will be made visible together, and
	will fade in and out at the same time.

	Each POI group knows if it contains point or area markers, as area markers (country, region, park...)
	are only visible at a zoom _range_, while point markers are visible above a zoom _threshold_. This logic
	sits in cullGroupToZoomRange()

	The PoiRenderer also provides the activePoiHashes comp-prop to export the list of exactly which POIs
	are rendered. This list is fed to the LabelView that needs the detailed information.
*/

class PoiRenderer {
	typealias RenderList = ContiguousArray<PoiGroup>
	
	static let kMaxVisiblePoiMarkers = 8192
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
	
	var poiGroups : [PoiGroup]
	var poiVisibility: [Int : Visibility] = [:]
	var renderLists: [RenderList] = []
	var frameSwitchSemaphore = DispatchSemaphore(value: 1)
	
	let device: MTLDevice
	let pipeline: MTLRenderPipelineState
	let instanceUniforms: [MTLBuffer]
	var framePoiMarkerCount: [Int] = []
	var poiMarkersHighwaterMark: Int = 0
	
	let markerAtlas: MTLTexture
	let poiMarkerPrimitive: BaseRenderPrimitive<Vertex>!

	var rankThreshold: Float = -1.0
	var poiBaseSize: Float = 0.0
	
	init(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat, bufferCount: Int,
				withVisibleContinents continents: GeoContinentMap,
				countries: GeoCountryMap,
				provinces: GeoProvinceMap) {
		
		let shaderLib = device.makeDefaultLibrary()!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.sampleCount = 4
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
			self.renderLists = Array(repeating: RenderList(), count: bufferCount)
			self.framePoiMarkerCount = Array(repeating: 0, count: bufferCount)
			self.instanceUniforms = (0..<bufferCount).map { _ in
				return device.makeBuffer(length: PoiRenderer.kMaxVisiblePoiMarkers * MemoryLayout<InstanceUniform>.stride, options: .storageModeShared)!
			}
			self.poiMarkerPrimitive = makePoiPrimitive(in: device)
		} catch let error {
			fatalError(error.localizedDescription)
		}
		
		let visibleContinentPoiGroups = continents.values.flatMap { sortPlacesIntoPoiGroups($0.places, in: $0) }
		let visibleCountryPoiGroups = countries.values.flatMap { sortPlacesIntoPoiGroups($0.places, in: $0) }
		let visibleProvincePoiGroups = provinces.values.flatMap { sortPlacesIntoPoiGroups($0.places, in: $0) }
		
		poiGroups = visibleContinentPoiGroups + visibleCountryPoiGroups + visibleProvincePoiGroups
		
		markerAtlas = loadMarkerAtlas("MarkerAtlas", inDevice: device)
	}
	
	var activePoiHashes: Set<Int> {
		let visiblePoiGroups = poiGroups.filter { self.poiVisibility[$0.hashValue] != nil }
		return Set(visiblePoiGroups.flatMap { $0.poiHashes })
	}
	
	func updatePoiGroups<T:GeoNode>(for node: T, with subRegions: Set<T.SubType>) where T.SubType : GeoPlaceContainer {
		let removedRegionsHash = node.geographyId.hashed
		poiGroups = poiGroups.filter { $0.ownerHash != removedRegionsHash }
		
		let subregionPrimitives = subRegions.flatMap { sortPlacesIntoPoiGroups($0.places, in: $0) }
		poiGroups.append(contentsOf: subregionPrimitives)
		
		for newRegion in subregionPrimitives {
			if Float(newRegion.rank) <= rankThreshold {
				poiVisibility.updateValue(.visible, forKey: newRegion.hashValue)
			}
		}
	}
	
	func prepareFrame(visibleSet: Set<RegionHash>, zoom: Float, zoomRate: Float, bufferIndex: Int) {
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
		
		let poiZoom = zoom / (1.0 - zoomRate + zoomRate * Stylesheet.shared.poiZoomBias.value)	// POIs become larger at closer zoom levels
		let poiScreenSize: Float = 2.0 / poiZoom
		let newRankThreshold = updateZoomThreshold(viewZoom: zoom)
		
		let poiGroupsInFrame = poiGroups.filter { $0.representsArea == false }					// Hide area markers (but keep the labels)
																		.filter { visibleSet.contains($0.ownerHash) }	// Hide POI groups outside the frame
																		.filter { poiVisibility[$0.hashValue] != nil }	// Don't render hidden POI groups
		
		let poiBuffer = generatePoiMarkerGeometry(poiGroups: poiGroupsInFrame,
																							visibilities: poiVisibility,
																							maxMarkers: PoiRenderer.kMaxVisiblePoiMarkers)
		guard poiBuffer.count < PoiRenderer.kMaxVisiblePoiMarkers else {
			fatalError("POI marker buffer blew out at \(poiBuffer.count) markers (max \(PoiRenderer.kMaxVisiblePoiMarkers))")
		}
		
		let frameRenderList = RenderList(poiGroupsInFrame.map { $0 })
		frameSwitchSemaphore.wait()
			self.renderLists[bufferIndex] = frameRenderList
			self.instanceUniforms[bufferIndex].contents().copyMemory(from: poiBuffer, byteCount: MemoryLayout<InstanceUniform>.stride * poiBuffer.count)
			self.framePoiMarkerCount[bufferIndex] = poiBuffer.count
			self.poiBaseSize = poiScreenSize
			self.rankThreshold = newRankThreshold
			if poiBuffer.count > poiMarkersHighwaterMark {
				poiMarkersHighwaterMark = poiBuffer.count
				print("POI renderer used a max of \(poiMarkersHighwaterMark) markers")
			}
		frameSwitchSemaphore.signal()
	}
	
	func updateZoomThreshold(viewZoom: Float) -> Float{
		if rankThreshold == viewZoom {
			return rankThreshold
		}
		
		let previousPois = Set(poiGroups.filter { cullGroupToZoomRange(poiGroup: $0, zoom: rankThreshold) })
		let visiblePois = Set(poiGroups.filter { cullGroupToZoomRange(poiGroup: $0, zoom: viewZoom) })

		let poisToHide = previousPois.subtracting(visiblePois)	// Culled this frame
		let poisToShow = visiblePois.subtracting(previousPois) // Shown this frame
		
		for p in poisToHide {
			poiVisibility.updateValue(.fadeOut(startTime: Date()), forKey: p.hashValue)
		}
		
		for p in poisToShow {
			poiVisibility.updateValue(.fadeIn(startTime: Date()), forKey: p.hashValue)
		}
		
		return viewZoom
	}
	
	func cullGroupToZoomRange(poiGroup: PoiGroup, zoom: Float) -> Bool {
		var minZoom: Float = 0.0, maxZoom: Float = 1000.0
		switch (poiGroup.rank, poiGroup.representsArea) {
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
	
	func renderWorld(inProjection projection: simd_float4x4, inEncoder encoder: MTLRenderCommandEncoder, bufferIndex: Int) {
		encoder.pushDebugGroup("Render POI groups")
		defer {
			encoder.popDebugGroup()
		}
		
		frameSwitchSemaphore.wait()
			var frameUniforms = FrameUniforms(mvpMatrix: projection,
																				rankThreshold: self.rankThreshold,
																				poiBaseSize: self.poiBaseSize)
			let instances = self.instanceUniforms[bufferIndex]
			let count = framePoiMarkerCount[bufferIndex]
		frameSwitchSemaphore.signal()
		
		if count == 0 {
			return
		}
		
		encoder.setRenderPipelineState(pipeline)
		
		encoder.setVertexBytes(&frameUniforms, length: MemoryLayout<FrameUniforms>.stride, index: 1)
		encoder.setVertexBuffer(instances, offset: 0, index: 2)
		
		renderInstanced(primitive: poiMarkerPrimitive, count: count, into: encoder)
	}
}

// MARK: Texture management
func loadMarkerAtlas(_ name: String, inDevice device: MTLDevice) -> MTLTexture {
	let loader = MTKTextureLoader(device: device)
	let path = Bundle.main.url(forResource: "atlas", withExtension: "pvr")!
	guard let atlas = try? loader.newTexture(URL: path, options: .none) else {
		fatalError("Could not load marker atlas")
	}
	
	print("Loaded marker atlas with \(atlas.mipmapLevelCount) mip levels")
	
	return atlas
}

// MARK: Generating POI groups
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

func sortPlacesIntoPoiGroups<T: GeoIdentifiable>(_ places: Set<GeoPlace>, in container: T) -> [PoiGroup] {
	let placeMarkers = places.filter { $0.kind != .Region }
	let areaMarkers = places.filter { $0.kind == .Region }
	let rankedPlaces = bucketPlaceMarkers(places: placeMarkers)
	let rankedAreas = bucketPlaceMarkers(places: areaMarkers )
	
	let placeGroups = rankedPlaces.map { (rank, pois) -> PoiGroup in
		let locations: [Vertex] = pois.map { $0.location }
		let hashes = pois.map { $0.hashValue }
		return PoiGroup(locations: locations,
										rank: rank,
										representsArea: false,
										ownerHash: container.geographyId.hashed,
										poiHashes: hashes,
										debugName: "\(container.name) - poi group @ \(rank)")
	}
	
	let areaGroups = rankedAreas.map { (rank, pois) -> PoiGroup in
		let locations: [Vertex] = pois.map { $0.location }
		let hashes = pois.map { $0.hashValue }
		return PoiGroup(locations: locations,
										rank: rank,
										representsArea: true,
										ownerHash: container.geographyId.hashed,
										poiHashes: hashes,
										debugName: "\(container.name) - area group @ \(rank)")
	}
	
	let poiGroups: [PoiGroup] = placeGroups + areaGroups
	return poiGroups
}

fileprivate func makePoiPrimitive(in device: MTLDevice) -> RenderPrimitive {
	let vertices: [Vertex] = [
		Vertex(-0.5, -0.5),
		Vertex(+0.5, -0.5),
		Vertex(+0.5, +0.5),
		Vertex(-0.5, +0.5)
	]
	let indices: [UInt16] = [
		0, 1, 2, 0, 2, 3
	]
	
	return RenderPrimitive(	polygons: [vertices],
													indices: [indices],
													drawMode: .triangle,
													device: device,
													color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0),
													ownerHash: 0,
													debugName: "POI primitive")
}

fileprivate func generatePoiMarkerGeometry(poiGroups: [PoiGroup], visibilities: [Int : PoiRenderer.Visibility], maxMarkers: Int) -> Array<InstanceUniform> {
	let markerCount = poiGroups.reduce(0) { $0 + $1.locations.count }
	var markers = Array<InstanceUniform>()
	markers.reserveCapacity(markerCount)
	for group in poiGroups {
		for marker in group.locations {
			markers.append(InstanceUniform(
				position: simd_float2(x: marker.x, y: marker.y),
				progress: 1.0	// $ lookup in visibility + small offset of .2 bias, max
			))
		}
	}
	return markers
}
