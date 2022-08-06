//
//  MetalRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-05-03.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation
import Metal
import MetalKit

class MetalRenderer {
	var device: MTLDevice!
	var commandQueue: MTLCommandQueue
	var latestFrame = Date()
	var modelViewProjectionMatrix = simd_float4x4()
	var zoomLevel: Float = 0.0
	
	// Parallel rendering setup
	let maxInflightFrames = 3
	var frameId = 0
	let frameSemaphore: DispatchSemaphore
	let encodingQueue = DispatchQueue(label: "Parallel command encoding", attributes: .concurrent)
	
	// Post-processing shader target
	var renderTargetTexture: MTLTexture!
	
	// App renderers
	var regionRenderer: RegionRenderer
	var poiRenderer: PoiRenderer
	var effectRenderer: EffectRenderer
	var selectionRenderer: SelectionRenderer
	var continentBorderRenderer: BorderRenderer<GeoContinent>
	var countryBorderRenderer: BorderRenderer<GeoCountry>
	var provinceBorderRenderer: BorderRenderer<GeoProvince>
	var debugRenderer: DebugRenderer
	
	init(in view: MTKView, forWorld world: RuntimeWorld) {
		device = MTLCreateSystemDefaultDevice()
		commandQueue = device.makeCommandQueue()!
		view.device = device
		view.colorPixelFormat = .bgra8Unorm
		
		// Create renderers
		regionRenderer = RegionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		continentBorderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames, maxSegments: 150000, label: "Continent border renderer")
		countryBorderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames, maxSegments: 50000, label: "Country border renderer")
		provinceBorderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames, maxSegments: 30000, label: "Province border renderer")
		selectionRenderer = SelectionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		poiRenderer = PoiRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
															withVisibleContinents: world.availableContinents,
															countries: world.availableCountries,
															provinces: world.availableProvinces)
		
		effectRenderer = EffectRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		debugRenderer = DebugRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		
		frameSemaphore = DispatchSemaphore(value: maxInflightFrames)
		
		let style = Stylesheet.shared
		continentBorderRenderer.setStyle(innerWidth: style.continentBorderWidthInner.value,
																		 outerWidth: style.continentBorderWidthOuter.value,
																		 color: style.continentBorderColor.float4)
		countryBorderRenderer.setStyle(innerWidth: style.countryBorderWidthInner.value,
																		 outerWidth: style.countryBorderWidthOuter.value,
																		 color: style.countryBorderColor.float4)
		provinceBorderRenderer.setStyle(innerWidth: style.provinceBorderWidthInner.value,
																		 outerWidth: style.provinceBorderWidthOuter.value,
																		 color: style.provinceBorderColor.float4)
	}
	
	func updateProjection(viewSize: CGSize, mapSize: CGSize, centeredOn offset: CGPoint, zoomedTo zoom: Float) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: viewSize,
																											mapSize: mapSize,
																											centeredOn: offset,
																											zoomedTo: zoom)
	}
	
	func prepareFrame(forWorld worldState: RuntimeWorld, zoomRate: Float) {
		frameSemaphore.wait()
		frameId += 1
		let available = AppDelegate.sharedUserState.availableSet
		let visible = AppDelegate.sharedUIState.visibleRegionHashes
		let visited = AppDelegate.sharedUserState.visitedPlaces
		let renderSet = available.intersection(visible)
		let borderedContinents = worldState.allContinents.filter { visible.contains($0.key) }	// All visible continents (even if visited)
		let borderedCountries = worldState.visibleCountries
		let borderedProvinces = worldState.visibleProvinces.filter { !visited.contains($0.key) }	// Visited provinces have no borders
		let poiZoom = zoomLevel / (1.0 - zoomRate + zoomRate * Stylesheet.shared.poiZoomBias.value)	// Pois become larger at closer zoom levels
		let bufferIndex = frameId % maxInflightFrames
		
		effectRenderer.prepareFrame(bufferIndex: bufferIndex)
		regionRenderer.prepareFrame(visibleContinentSet: worldState.visibleContinents.keys,
																visibleCountrySet: worldState.visibleCountries.keys,
																visibleProvinceSet: worldState.visibleProvinces.keys,
																visitedSet: visited, regionContinentMap: worldState.continentForRegion, bufferIndex: bufferIndex)
		continentBorderRenderer.prepareFrame(borderedRegions: borderedContinents,
																			   zoom: zoomLevel, zoomRate: zoomRate, bufferIndex: bufferIndex)
		countryBorderRenderer.prepareFrame(borderedRegions: borderedCountries,
																			 zoom: zoomLevel, zoomRate: zoomRate, bufferIndex: bufferIndex)
		provinceBorderRenderer.prepareFrame(borderedRegions: borderedProvinces,
																			  zoom: zoomLevel, zoomRate: zoomRate, bufferIndex: bufferIndex)
							 
		poiRenderer.prepareFrame(visibleSet: renderSet, zoom: poiZoom, zoomRate: zoomRate, bufferIndex: bufferIndex)
		selectionRenderer.prepareFrame(zoomLevel: zoomLevel)
		debugRenderer.prepareFrame(bufferIndex: bufferIndex)
	}
	
	func render(forWorld worldState: RuntimeWorld, into view: MTKView) {
		guard let drawable = view.currentDrawable else { frameSemaphore.signal(); return }
		
		if renderTargetTexture == nil || renderTargetTexture.width != drawable.texture.width || renderTargetTexture.height != drawable.texture.height {
			// $ needs one per inflight frame
			let renderTargetDescriptor = MTLTextureDescriptor()
			renderTargetDescriptor.textureType = MTLTextureType.type2DMultisample
			renderTargetDescriptor.width = Int(view.drawableSize.width)
			renderTargetDescriptor.height = Int(view.drawableSize.height)
			renderTargetDescriptor.pixelFormat = view.colorPixelFormat
			renderTargetDescriptor.storageMode = .private
			renderTargetDescriptor.sampleCount = 4
			renderTargetDescriptor.usage = [.renderTarget, .shaderRead]
			
			renderTargetTexture = device.makeTexture(descriptor: renderTargetDescriptor)
		}
		
		let passDescriptor = MTLRenderPassDescriptor()
		let ocean = Stylesheet.shared.oceanColor.components
		passDescriptor.colorAttachments[0].resolveTexture = drawable.texture
		passDescriptor.colorAttachments[0].texture = renderTargetTexture
		passDescriptor.colorAttachments[0].loadAction = .clear
		passDescriptor.colorAttachments[0].storeAction = .multisampleResolve
		passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: Double(ocean.r), green: Double(ocean.g), blue: Double(ocean.b), alpha: Double(ocean.a))
		
		guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
		commandBuffer.label = "Geography buffer"
		commandBuffer.addCompletedHandler { buffer in
			drawable.present()						// Render
			self.frameSemaphore.signal()	// Make this in-flight frame available
		}

		let mvpMatrix = modelViewProjectionMatrix
		let bufferIndex = frameId % maxInflightFrames
		
		guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
		encoder.label = "Main render pass encoder @ \(frameId)"
		
		self.regionRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.continentBorderRenderer.renderBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.countryBorderRenderer.renderBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.provinceBorderRenderer.renderBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.effectRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.selectionRenderer.renderSelection(inProjection: mvpMatrix, inEncoder: encoder)
		self.poiRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.debugRenderer.renderMarkers(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		
		encoder.endEncoding()
		commandBuffer.commit()
		
//		commandQueue.insertDebugCaptureBoundary()	// $ For GPU Frame capture
	}
	
	func shouldIdle(appUpdated: Bool) -> Bool {
		var sleepRenderer = false
		let needsRender = appUpdated || effectRenderer.animating
		
		if needsRender {
			latestFrame = Date()
		} else if Date().timeIntervalSince(latestFrame) > 1.0 {
			sleepRenderer = true
		}
		return sleepRenderer
	}
}

extension Color {
	var vector: simd_float4 {
		return simd_float4(arrayLiteral: r, g, b, a)
	}
}
