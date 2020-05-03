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
import GLKit

class MetalRenderer {
	var device: MTLDevice!
	var commandQueue: MTLCommandQueue! // $ Pass multiple into the renderers
	var latestFrame = Date()
	var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity	// $ Drop GLK

	// App renderers
	var regionRenderer: RegionRenderer
	var poiRenderer: PoiRenderer
	var effectRenderer: EffectRenderer
	var selectionRenderer: SelectionRenderer
	var borderRenderer: BorderRenderer
	
	init(in view: MTKView, forWorld world: RuntimeWorld) {
		device = MTLCreateSystemDefaultDevice()
		commandQueue = device.makeCommandQueue()
		view.device = device
		
		// Create renderers
		regionRenderer = RegionRenderer()!
		poiRenderer = PoiRenderer(withVisibleContinents: world.availableContinents,
															countries: world.availableCountries,
															provinces: world.availableProvinces)!
		
		effectRenderer = EffectRenderer()!
		selectionRenderer = SelectionRenderer()!
		borderRenderer = BorderRenderer()!
	}
	
	func updateProjection(viewSize: CGSize, mapSize: CGSize, centeredOn offset: CGPoint, zoomedTo zoom: Float) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: viewSize,
																											mapSize: mapSize,
																											centeredOn: offset,
																											zoomedTo: zoom)

		selectionRenderer.updateStyle(zoomLevel: zoom)
		borderRenderer.updateStyle(zoomLevel: zoom)
		poiRenderer.updateZoomThreshold(viewZoom: zoom)
		poiRenderer.updateStyle(zoomLevel: zoom)
	}
	
	func prepareFrame(forWorld worldState: RuntimeWorld) {
		let visible = AppDelegate.sharedUIState.visibleRegionHashes
		let borderedContinents = worldState.allContinents.filter { visible.contains($0.key) }	// All visible continents (even if visited)

		effectRenderer.updatePrimitives()
		borderRenderer.prepareGeometry(visibleContinents: borderedContinents, visibleCountries: worldState.visibleCountries)
		poiRenderer.updateFades()
	}
	
	func render(forWorld worldState: RuntimeWorld, into drawable: CAMetalDrawable) {
		let renderPassDescriptor = MTLRenderPassDescriptor()
		renderPassDescriptor.colorAttachments[0].texture = drawable.texture
		renderPassDescriptor.colorAttachments[0].loadAction = .clear
		renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.7, alpha: 1.0)
		
		guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
		guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

		//		let available = AppDelegate.sharedUserState.availableSet
		//		let visible = AppDelegate.sharedUIState.visibleRegionHashes
		//		let renderSet = available.intersection(visible)
		//		let borderedContinents = visible.intersection(world.allContinents.keys)	// All visible continents (even if visited)
		//		let borderedCountries = Set(world.visibleCountries.keys)
		//
		//		borderRenderer.renderContinentBorders(borderedContinents, inProjection: modelViewProjectionMatrix)
		//		regionRenderer.renderWorld(visibleSet: renderSet, inProjection: modelViewProjectionMatrix)
		//		borderRenderer.renderCountryBorders(borderedCountries, inProjection: modelViewProjectionMatrix)
		//		poiRenderer.renderWorld(visibleSet: renderSet, inProjection: modelViewProjectionMatrix)
		//		effectRenderer.renderWorld(inProjection: modelViewProjectionMatrix)
		//		selectionRenderer.renderSelection(inProjection: modelViewProjectionMatrix)
		
		// //		DebugRenderer.shared.renderMarkers(inProjection: modelViewProjectionMatrix)
		
		commandEncoder.endEncoding()
		commandBuffer.present(drawable)
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
