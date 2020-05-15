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
		regionRenderer = RegionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		borderRenderer = BorderRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		selectionRenderer = SelectionRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		poiRenderer = PoiRenderer(withDevice: device, pixelFormat: view.colorPixelFormat, bufferCount: maxInflightFrames,
															withVisibleContinents: world.availableContinents,
															countries: world.availableCountries,
															provinces: world.availableProvinces)
		
		effectRenderer = EffectRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		debugRenderer = DebugRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		
		frameSemaphore = DispatchSemaphore(value: maxInflightFrames)
	}
	
	func updateProjection(viewSize: CGSize, mapSize: CGSize, centeredOn offset: CGPoint, zoomedTo zoom: Float) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: viewSize,
																											mapSize: mapSize,
																											centeredOn: offset,
																											zoomedTo: zoom)
	}
	
	func zoomedTo(_ zoom: Float) {
		selectionRenderer.updateStyle(zoomLevel: zoom)
		borderRenderer.updateStyle(zoomLevel: zoom)
		poiRenderer.updateZoomThreshold(viewZoom: zoom)
		poiRenderer.updateStyle(zoomLevel: zoom)
	}
	
	func prepareFrame(forWorld worldState: RuntimeWorld) {
		frameSemaphore.wait()
		frameId += 1
		let available = AppDelegate.sharedUserState.availableSet
		let visible = AppDelegate.sharedUIState.visibleRegionHashes
		let renderSet = available.intersection(visible)
		let borderedContinents = worldState.allContinents.filter { visible.contains($0.key) }	// All visible continents (even if visited)

		let bufferIndex = frameId % maxInflightFrames
		effectRenderer.updatePrimitives()
		regionRenderer.prepareFrame(visibleSet: renderSet)
		borderRenderer.prepareFrame(visibleContinents: borderedContinents, visibleCountries: worldState.visibleCountries)
		poiRenderer.prepareFrame(visibleSet: renderSet, frameIndex: bufferIndex)
	}
	
	func render(forWorld worldState: RuntimeWorld, into drawable: CAMetalDrawable) {
		let clearPassDescriptor = MTLRenderPassDescriptor()
		clearPassDescriptor.colorAttachments[0].texture = drawable.texture
		clearPassDescriptor.colorAttachments[0].loadAction = .clear
		clearPassDescriptor.colorAttachments[0].storeAction = .dontCare
		clearPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.7, alpha: 1.0)
		let addPassDescriptor = clearPassDescriptor.copy() as! MTLRenderPassDescriptor
		addPassDescriptor.colorAttachments[0].loadAction = .load
		addPassDescriptor.colorAttachments[0].storeAction = .dontCare
				
		// Create parallel command buffers and enqueue in order
		guard let geographyBuffer = commandQueue.makeCommandBuffer() else { return }
		guard let markerBuffer = commandQueue.makeCommandBuffer() else { return }
		guard let overlayBuffer = commandQueue.makeCommandBuffer() else { return }
		
		geographyBuffer.label = "Geography buffer"
		geographyBuffer.enqueue()
		markerBuffer.label = "Marker buffer"
		markerBuffer.enqueue()
		overlayBuffer.label = "Overlay buffer"
		overlayBuffer.enqueue()
		
		// $ Mark buffers immutable
		
		let available = AppDelegate.sharedUserState.availableSet
		let visible = AppDelegate.sharedUIState.visibleRegionHashes
		let renderSet = available.intersection(visible)
		let borderedContinents = visible.intersection(worldState.allContinents.keys)	// All visible continents (even if visited)
		let borderedCountries = Set(worldState.visibleCountries.keys)
		
		let mvpMatrix = modelViewProjectionMatrix
		let bufferIndex = frameId % maxInflightFrames
		
		overlayBuffer.addCompletedHandler { buffer in
			drawable.present()
			self.frameSemaphore.signal()
		}
		
		encodingQueue.async(execute: makeRenderPass(geographyBuffer, clearPassDescriptor) { (encoder) in
			self.borderRenderer.renderContinentBorders(borderedContinents, inProjection: mvpMatrix, inEncoder: encoder)
			self.regionRenderer.renderWorld(visibleSet: renderSet, inProjection: mvpMatrix, inEncoder: encoder)
			self.borderRenderer.renderCountryBorders(borderedCountries, inProjection: mvpMatrix, inEncoder: encoder)
		})

		encodingQueue.async(execute: makeRenderPass(markerBuffer, addPassDescriptor) { (encoder) in
			self.poiRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		})
		
		encodingQueue.async(execute: makeRenderPass(overlayBuffer, addPassDescriptor) { (encoder) in
			self.effectRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder)
			self.selectionRenderer.renderSelection(inProjection: mvpMatrix, inEncoder: encoder)
			//		DebugRenderer.shared.renderMarkers(inProjection: modelViewProjectionMatrix)
		})

		//		commandQueue.insertDebugCaptureBoundary()	// $ For GPU Frame capture
	}
	
	typealias MapRenderPass = () -> ()
	func makeRenderPass(_ buffer: MTLCommandBuffer, _ renderPass: MTLRenderPassDescriptor, render: @escaping (MTLRenderCommandEncoder) -> ()) -> MapRenderPass {
		return {
			guard let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
			encoder.label = "\(buffer.label ?? "Unnamed") encoder @ \(self.frameId)"
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
