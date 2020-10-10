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
		debugRenderer = DebugRenderer(withDevice: device, pixelFormat: view.colorPixelFormat)
		
		frameSemaphore = DispatchSemaphore(value: maxInflightFrames)
	}
	
	func updateProjection(viewSize: CGSize, mapSize: CGSize, centeredOn offset: CGPoint, zoomedTo zoom: Float) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: viewSize,
																											mapSize: mapSize,
																											centeredOn: offset,
																											zoomedTo: zoom)
	}
	
	func prepareFrame(forWorld worldState: RuntimeWorld) {
		frameSemaphore.wait()
		frameId += 1
		let available = AppDelegate.sharedUserState.availableSet
		let visible = AppDelegate.sharedUIState.visibleRegionHashes
		let renderSet = available.intersection(visible)
		let renderContinentSet = renderSet.filter { worldState.visibleContinents.keys.contains($0) }
		let renderCountrySet = renderSet.filter { worldState.visibleCountries.keys.contains($0) }
		let renderProvinceSet = renderSet.filter { worldState.visibleProvinces.keys.contains($0) }
		let borderedContinents = worldState.allContinents.filter { visible.contains($0.key) }	// All visible continents (even if visited)

		let bufferIndex = frameId % maxInflightFrames
		effectRenderer.prepareFrame(bufferIndex: bufferIndex)
		regionRenderer.prepareFrame(visibleContinentSet: renderContinentSet, visibleCountrySet: renderCountrySet, visibleProvinceSet: renderProvinceSet, bufferIndex: bufferIndex)
		borderRenderer.prepareFrame(visibleContinents: borderedContinents, visibleCountries: worldState.visibleCountries, zoom: zoomLevel, bufferIndex: bufferIndex)
		poiRenderer.prepareFrame(visibleSet: renderSet, zoom: zoomLevel, bufferIndex: bufferIndex)
		selectionRenderer.prepareFrame(zoomLevel: zoomLevel)
	}
	
	func render(forWorld worldState: RuntimeWorld, into drawable: CAMetalDrawable) {
		let clearPassDescriptor = MTLRenderPassDescriptor()
		clearPassDescriptor.colorAttachments[0].texture = drawable.texture
		clearPassDescriptor.colorAttachments[0].loadAction = .clear
		let clearColor = Stylesheet.shared.oceanColor.components
		clearPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: Double(clearColor.r),
																																			 green: Double(clearColor.g),
																																			 blue: Double(clearColor.b),
																																			 alpha: Double(clearColor.a))
		let addPassDescriptor = clearPassDescriptor.copy() as! MTLRenderPassDescriptor
		addPassDescriptor.colorAttachments[0].loadAction = .load
				
		// Create parallel command buffers and enqueue in order
		guard let geographyBuffer = commandQueue.makeCommandBuffer() else { return }
		guard let markerBuffer = commandQueue.makeCommandBuffer() else { return }
		guard let overlayBuffer = commandQueue.makeCommandBuffer() else { return }
		
		geographyBuffer.label = "Geography buffer"
		geographyBuffer.enqueue()
		overlayBuffer.label = "Overlay buffer"
		overlayBuffer.enqueue()
		markerBuffer.label = "Marker buffer"
		markerBuffer.enqueue()
		
		let mvpMatrix = modelViewProjectionMatrix
		let bufferIndex = frameId % maxInflightFrames
		
		let geographyPass = makeRenderPass(geographyBuffer, clearPassDescriptor) { (encoder) in
			self.borderRenderer.renderContinentBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
			self.regionRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
			self.borderRenderer.renderCountryBorders(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		}
		
		let overlayPass = makeRenderPass(overlayBuffer, addPassDescriptor) { (encoder) in
			self.effectRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
			self.selectionRenderer.renderSelection(inProjection: mvpMatrix, inEncoder: encoder)
			//		DebugRenderer.shared.renderMarkers(inProjection: modelViewProjectionMatrix)
		}
		
		let markerPass = makeRenderPass(markerBuffer, addPassDescriptor) { (encoder) in
			self.poiRenderer.renderWorld(inProjection: mvpMatrix, inEncoder: encoder, bufferIndex: bufferIndex)
		}
		
		markerBuffer.addCompletedHandler { buffer in
			drawable.present()
			self.frameSemaphore.signal()
		}
		
		encodingQueue.async(execute: geographyPass)
		encodingQueue.async(execute: overlayPass)
		encodingQueue.async(execute: markerPass)
		
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
