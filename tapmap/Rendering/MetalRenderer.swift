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
	var msaaRenderTarget: [MTLTexture]
	var sseRenderTarget: [MTLTexture]
	
	// App renderers
	var regionRenderer: RegionRenderer
	var poiRenderer: PoiRenderer
	var effectRenderer: EffectRenderer
	var selectionRenderer: SelectionRenderer
	var continentBorderRenderer: BorderRenderer<GeoContinent>
	var countryBorderRenderer: BorderRenderer<GeoCountry>
	var provinceBorderRenderer: BorderRenderer<GeoProvince>
	var debugRenderer: DebugRenderer
	var postProcessingRenderer: PostProcessingRenderer
	
	init(in view: MTKView, forWorld world: RuntimeWorld) {
		let newDevice = MTLCreateSystemDefaultDevice()!
		device = newDevice
		commandQueue = device.makeCommandQueue()!
		view.device = device
		view.colorPixelFormat = .bgra8Unorm	// Also used in setupRenderTargets
		
		// Create renderers
		regionRenderer = RegionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		continentBorderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
																						 maxSegments: 15000, label: "Continent border renderer")
		countryBorderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
																					 maxSegments: 30000, label: "Country border renderer")
		provinceBorderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
																						maxSegments: 30000, label: "Province border renderer")
		selectionRenderer = SelectionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		poiRenderer = PoiRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
															withVisibleContinents: world.availableContinents,
															countries: world.availableCountries,
															provinces: world.availableProvinces)
		
		effectRenderer = EffectRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		debugRenderer = DebugRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		postProcessingRenderer = PostProcessingRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
																										drawableSize: simd_float2(Float(view.drawableSize.width), Float(view.drawableSize.height)))

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
		
		msaaRenderTarget = (0..<maxInflightFrames).map { i in
			return makeRenderTarget(inDevice: newDevice, width: Int(view.drawableSize.width), height: Int(view.drawableSize.height), bufferIndex: i)
		}
		sseRenderTarget = (0..<maxInflightFrames).map { i in
			return makeOffscreenTexture(inDevice: newDevice, width: Int(view.drawableSize.width), height: Int(view.drawableSize.height), bufferIndex: i)
		}
	}
	
	func updateProjection(viewSize: CGSize, mapSize: CGSize, centeredOn offset: CGPoint, zoomedTo zoom: Float) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: viewSize,
																											mapSize: mapSize,
																											centeredOn: offset,
																											zoomedTo: zoom)
	}
	
	func prepareFrame(forWorld worldState: RuntimeWorld, zoomRate: Float, inside renderBox: Aabb) {
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
																				 zoom: zoomLevel, zoomRate: zoomRate, inside: renderBox, bufferIndex: bufferIndex)
		countryBorderRenderer.prepareFrame(borderedRegions: borderedCountries,
																			 zoom: zoomLevel, zoomRate: zoomRate, inside: renderBox, bufferIndex: bufferIndex)
		provinceBorderRenderer.prepareFrame(borderedRegions: borderedProvinces,
																			  zoom: zoomLevel, zoomRate: zoomRate, inside: renderBox, bufferIndex: bufferIndex)
							 
		poiRenderer.prepareFrame(visibleSet: renderSet, zoom: poiZoom, zoomRate: zoomRate, bufferIndex: bufferIndex)
		selectionRenderer.prepareFrame(zoomLevel: zoomLevel, inside: renderBox, bufferIndex: bufferIndex)
		debugRenderer.prepareFrame(bufferIndex: bufferIndex)
		
		postProcessingRenderer.prepareFrame(offscreenTexture: sseRenderTarget[bufferIndex], bufferIndex: bufferIndex)
	}
	
	func render(forWorld worldState: RuntimeWorld, into view: MTKView) {
		guard let drawable = view.currentDrawable else { frameSemaphore.signal(); return }
		guard let renderPassDescriptor = view.currentRenderPassDescriptor else { frameSemaphore.signal(); return }
		
		guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
		commandBuffer.label = "Frame command buffer"
		commandBuffer.addCompletedHandler { buffer in
			drawable.present()						// Render
			self.frameSemaphore.signal()	// Make this in-flight frame available
		}

		let mvpMatrix = modelViewProjectionMatrix
		let bufferIndex = frameId % maxInflightFrames
		
		let ocean = Stylesheet.shared.oceanColor.components
		
		let mapRenderPassDescriptor = MTLRenderPassDescriptor()
		mapRenderPassDescriptor.colorAttachments[0].resolveTexture = sseRenderTarget[bufferIndex]
		mapRenderPassDescriptor.colorAttachments[0].texture = msaaRenderTarget[bufferIndex]
		mapRenderPassDescriptor.colorAttachments[0].loadAction = .clear
		mapRenderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
		mapRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: Double(ocean.r), green: Double(ocean.g), blue: Double(ocean.b), alpha: Double(ocean.a))
		
		guard let baseMapEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mapRenderPassDescriptor) else { return }
		baseMapEncoder.label = "Base map render pass encoder @ \(frameId)"
			self.regionRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: baseMapEncoder, bufferIndex: bufferIndex)
			self.continentBorderRenderer.renderBorders(inProjection: mvpMatrix, inEncoder: baseMapEncoder, bufferIndex: bufferIndex)
			self.countryBorderRenderer.renderBorders(inProjection: mvpMatrix, inEncoder: baseMapEncoder, bufferIndex: bufferIndex)
			self.provinceBorderRenderer.renderBorders(inProjection: mvpMatrix, inEncoder: baseMapEncoder, bufferIndex: bufferIndex)
			self.effectRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: baseMapEncoder, bufferIndex: bufferIndex)
		baseMapEncoder.endEncoding()
		
		renderPassDescriptor.colorAttachments[0].loadAction = .clear
		renderPassDescriptor.colorAttachments[0].storeAction = .store
		renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: Double(ocean.r), green: Double(ocean.g), blue: Double(ocean.b), alpha: Double(ocean.a))
		
		guard let sseCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
		sseCommandEncoder.label = "Screen-space effect render pass encoder @ \(frameId)"
			self.postProcessingRenderer.renderPostProcessing(inEncoder: sseCommandEncoder, bufferIndex: bufferIndex)
			self.selectionRenderer.renderSelection(inProjection: mvpMatrix, inEncoder: sseCommandEncoder, bufferIndex: bufferIndex)
			self.poiRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: sseCommandEncoder, bufferIndex: bufferIndex)
			self.debugRenderer.renderMarkers(inProjection: mvpMatrix, inEncoder: sseCommandEncoder, bufferIndex: bufferIndex)
		sseCommandEncoder.endEncoding()
		
		commandBuffer.commit()
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

fileprivate func makeRenderTarget(inDevice device: MTLDevice, width: Int, height: Int, bufferIndex: Int) -> MTLTexture {
	let renderTargetDescriptor = MTLTextureDescriptor()
	renderTargetDescriptor.textureType = MTLTextureType.type2DMultisample
	renderTargetDescriptor.width = width
	renderTargetDescriptor.height = height
	renderTargetDescriptor.pixelFormat = .bgra8Unorm
	renderTargetDescriptor.storageMode = .memoryless
	renderTargetDescriptor.sampleCount = 4
	renderTargetDescriptor.usage = [.renderTarget]
	let out = device.makeTexture(descriptor: renderTargetDescriptor)!
	out.label = "Fullscreen render target @ \(bufferIndex)"
	return out
}
 
fileprivate func makeOffscreenTexture(inDevice device: MTLDevice, width: Int, height: Int, bufferIndex: Int) -> MTLTexture {
	let sseTargetDescriptor = MTLTextureDescriptor()
	sseTargetDescriptor.textureType = MTLTextureType.type2D
	sseTargetDescriptor.width = width
	sseTargetDescriptor.height = height
	sseTargetDescriptor.pixelFormat = .bgra8Unorm
	sseTargetDescriptor.storageMode = .private
	sseTargetDescriptor.usage = [.renderTarget, .shaderRead]
	let out = device.makeTexture(descriptor: sseTargetDescriptor)!
	out.label = "Screen-space effect texture @ \(bufferIndex)"
	return out
}

extension Color {
	var vector: simd_float4 {
		return simd_float4(arrayLiteral: r, g, b, a)
	}
}
