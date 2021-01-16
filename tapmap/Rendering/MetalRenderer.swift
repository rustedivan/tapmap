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
	
	// App renderers
	var regionRenderer: RegionRenderer
	var poiRenderer: PoiRenderer
	var effectRenderer: EffectRenderer
	var selectionRenderer: SelectionRenderer
	var borderRenderer: BorderRenderer
	var debugRenderer: DebugRenderer
	
	init(in view: MTKView, forWorld world: RuntimeWorld) {
		device = MTLCreateSystemDefaultDevice()
		commandQueue = device.makeCommandQueue()!
		view.device = device
		view.colorPixelFormat = .bgra8Unorm
		
		// Create renderers
		regionRenderer = RegionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		borderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		selectionRenderer = SelectionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		poiRenderer = PoiRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
															withVisibleContinents: world.availableContinents,
															countries: world.availableCountries,
															provinces: world.availableProvinces)
		
		effectRenderer = EffectRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		debugRenderer = DebugRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames)
		
		frameSemaphore = DispatchSemaphore(value: maxInflightFrames)
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
		let renderContinentSet = renderSet.filter { worldState.visibleContinents.keys.contains($0) }
		let renderCountrySet = renderSet.filter { worldState.visibleCountries.keys.contains($0) }
		let renderProvinceSet = renderSet.filter { worldState.visibleProvinces.keys.contains($0) }
		let borderedContinents = worldState.allContinents.filter { visible.contains($0.key) }	// All visible continents (even if visited)
		let borderedCountries = worldState.visibleCountries
		let borderedProvinces = worldState.visibleProvinces.filter { !visited.contains($0.key) }	// Visited provinces have no borders
		let poiZoom = zoomLevel / (1.0 - zoomRate + zoomRate * Stylesheet.shared.poiZoomBias.value)	// Pois become larger at closer zoom levels
		let bufferIndex = frameId % maxInflightFrames
		effectRenderer.prepareFrame(bufferIndex: bufferIndex)
		regionRenderer.prepareFrame(visibleContinentSet: renderContinentSet, visibleCountrySet: renderCountrySet, visibleProvinceSet: renderProvinceSet, visitedSet: visited, regionContinentMap: worldState.continentForRegion, bufferIndex: bufferIndex)
		borderRenderer.prepareFrame(borderedContinents: borderedContinents, borderedCountries: borderedCountries, borderedProvinces: borderedProvinces, zoom: zoomLevel, zoomRate: zoomRate, bufferIndex: bufferIndex)
		poiRenderer.prepareFrame(visibleSet: renderSet, zoom: poiZoom, zoomRate: zoomRate, bufferIndex: bufferIndex)
		selectionRenderer.prepareFrame(zoomLevel: zoomLevel)
		debugRenderer.prepareFrame(bufferIndex: bufferIndex)
	}
	
	func render(forWorld worldState: RuntimeWorld, into view: MTKView) {
		guard let drawable = view.currentDrawable else { frameSemaphore.signal(); return }
		
		guard let passDescriptor = view.currentRenderPassDescriptor else { frameSemaphore.signal(); return }
		let ocean = Stylesheet.shared.oceanColor.components
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
		
		// self.borderRenderer.renderContinentBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.regionRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.borderRenderer.renderCountryBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.borderRenderer.renderProvinceBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.effectRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.selectionRenderer.renderSelection(inProjection: mvpMatrix, inEncoder: encoder)
		self.poiRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		self.debugRenderer.renderMarkers(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		
		encoder.endEncoding()
		commandBuffer.commit()
		
//		commandQueue.insertDebugCaptureBoundary()	// $ For GPU Frame capture
	}
	
	typealias MapRenderPass = () -> ()
	func makeRenderPass(_ buffer: MTLCommandBuffer, _ renderPass: MTLRenderPassDescriptor, render: @escaping (MTLRenderCommandEncoder) -> ()) -> MapRenderPass {
		let passLabel = "\(buffer.label ?? "Unnamed") encoder @ \(frameId)"
		return {
			guard let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
			encoder.label = passLabel
			render(encoder)
			encoder.endEncoding()
			buffer.commit()
		}
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
