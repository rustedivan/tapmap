//
//  GameViewController.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-03-31.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import GLKit
import OpenGLES

class MapViewController: GLKViewController, GLKViewControllerDelegate {
	@IBOutlet var scrollView: UIScrollView!
	@IBOutlet var placeName: UILabel!
	@IBOutlet var labelView: LabelView!
	
	// Presentation
	var geoWorld: GeoWorld!
	var regionRenderer: RegionRenderer!
	var poiRenderer: PoiRenderer!
	var effectRenderer: EffectRenderer!
	var selectionRenderer: SelectionRenderer!
	var dummyView: UIView!
	
	// Navigation
	var zoom: Float = 1.0
	var offset: CGPoint = .zero
	let mapSpace = CGRect(x: -180.0, y: -80.0, width: 360.0, height: 160.0)
	var mapFrame = CGRect.zero
	var lastRenderFrame: Int = Int.max
	var needsRender: Bool = true { didSet {
		if needsRender { self.isPaused = false }
	}}
	
	// Rendering
	var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
	var context: EAGLContext? = nil
	var geometryStreamer: GeometryStreamer!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let userState = AppDelegate.sharedUserState
		let uiState = AppDelegate.sharedUIState
		
		let path = Bundle.main.path(forResource: "world", ofType: "geo")!
		
		geometryStreamer = GeometryStreamer(attachFile: path)!
		
		uiState.worldQuadTree = geometryStreamer.loadWorldTree()
		geoWorld = geometryStreamer.loadGeoWorld()
		userState.buildWorldAvailability(withWorld: geoWorld)
		
		
		self.context = EAGLContext(api: .openGLES2)
		
		if !(self.context != nil) {
			print("Failed to create ES context")
		}
		
		let view = self.view as! GLKView
		view.context = self.context!
		view.drawableDepthFormat = .format24
		
		dummyView = UIView(frame: view.frame)
		scrollView.contentSize = dummyView.frame.size
		scrollView.addSubview(dummyView)
		dummyView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
		
		// Calculate view-space frame of the map (scale map to fit in view, calculate the vertical offset to center it)
		let heightDiff = dummyView.bounds.height - (mapSpace.height / (mapSpace.width / dummyView.bounds.width))
		mapFrame = dummyView.bounds.insetBy(dx: 0.0, dy: heightDiff / 2.0)
		
		let zoomLimits = mapZoomLimits(viewSize: view.frame.size, mapSize: mapSpace.size)
		scrollView.minimumZoomScale = zoomLimits.0
		scrollView.zoomScale = zoomLimits.0
		scrollView.maximumZoomScale = zoomLimits.1
		
		delegate = self
		
		EAGLContext.setCurrent(self.context)
		regionRenderer = RegionRenderer()
		poiRenderer = PoiRenderer(withVisibleContinents: userState.availableContinents,
															countries: userState.availableCountries,
															regions: userState.availableRegions)
		labelView.buildPoiPrimitives(withVisibleContinents: userState.availableContinents,
																 countries: userState.availableCountries,
																 regions: userState.availableRegions)
		poiRenderer.updateZoomThreshold(viewZoom: Float(scrollView!.zoomScale))
		effectRenderer = EffectRenderer()
		selectionRenderer = SelectionRenderer()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		
		if self.isViewLoaded && (self.view.window != nil) {
			self.view = nil
			
			if EAGLContext.current() === self.context {
				EAGLContext.setCurrent(nil)
			}
			self.context = nil
		}
	}
	
	@objc func handleTap(sender: UITapGestureRecognizer) {
		needsRender = true
		
		if sender.state == .ended {
			let viewP = sender.location(in: dummyView)
			let mapP = mapPoint(viewP, from: dummyView.bounds, to: mapFrame, space: mapSpace)
			let tapPoint = Vertex(Float(mapP.x), Float(mapP.y))
			
			let userState = AppDelegate.sharedUserState
			let uiState = AppDelegate.sharedUIState
			
			GeometryCounters.begin()
			defer { GeometryCounters.end() }
			
			// Filter out sets of closed, visible regions that contain the tap
			let candidateContinents = Set(userState.availableContinents		// Closed continents
				.filter { uiState.visibleRegionHashes.contains($0.key) }		// Visible continents
				.filter { boxContains($0.value.aabb, tapPoint) }						// Under the tap position
				.values)
			let candidateCountries = Set(userState.availableCountries
				.filter { uiState.visibleRegionHashes.contains($0.key) }
				.filter { boxContains($0.value.aabb, tapPoint) }
				.values)
			let candidateRegions = Set(userState.availableRegions
				.filter { uiState.visibleRegionHashes.contains($0.key) }
				.filter { boxContains($0.value.aabb, tapPoint) }
				.values)
			
			if let hitHash = pickFromTessellations(p: tapPoint, candidates: candidateContinents) {
				let hitContinent = userState.availableContinents[hitHash]!
				if processSelection(of: hitContinent, user: userState, ui: uiState) {
					processVisit(of: hitContinent, user: userState, ui: uiState)
				}
			} else if let hitHash = pickFromTessellations(p: tapPoint, candidates: candidateCountries) {
				let hitCountry = userState.availableCountries[hitHash]!
				if processSelection(of: hitCountry, user: userState, ui: uiState) {
					processVisit(of: hitCountry, user: userState, ui: uiState)
				}
			} else if let hitHash = pickFromTessellations(p: tapPoint, candidates: candidateRegions) {
				let hitRegion = userState.availableRegions[hitHash]!
				_ = processSelection(of: hitRegion, user: userState, ui: uiState)
			} else {
				uiState.clearSelection()
				selectionRenderer.clear()
			}
		}
		
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
	}
	
	func processSelection<T:GeoIdentifiable>(of hit: T, user: UserState, ui: UIState) -> Bool {
		placeName.text = hit.name
		if ui.selected(hit) {
			user.visitPlace(hit)
			return true
		} else {
			ui.selectRegion(hit)
			selectionRenderer.select(regionHash: hit.geographyId.hashed)
			return false
		}
	}
	
	func processVisit<T:GeoNode & GeoPlaceContainer>(of hit: T, user: UserState, ui: UIState)
		where T.SubType: GeoPlaceContainer {

		user.openPlace(hit)
		
		if geometryStreamer.renderPrimitive(for: hit.geographyId.hashed) != nil {
			effectRenderer.addOpeningEffect(for: hit.geographyId.hashed)
			geometryStreamer.evictPrimitive(for: hit.geographyId.hashed)
		}
		poiRenderer.updatePrimitives(for: hit, with: hit.children)
		labelView.updatePrimitives(for: hit, with: hit.children)
	}

	// MARK: - GLKView and GLKViewController delegate methods
	func glkViewControllerUpdate(_ controller: GLKViewController) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: scrollView.bounds.size,
																											mapSize: mapSpace.size,
																											centeredOn: offset,
																											zoomedTo: zoom)
		effectRenderer.updatePrimitives()
		selectionRenderer.updateStyle(zoomLevel: zoom)
		poiRenderer.updateStyle(zoomLevel: zoom)
		poiRenderer.updateFades()
		labelView.updateLabels(for: poiRenderer.activePoiHashes,
													 inArea: visibleLongLat(viewBounds: view.bounds),
													 atZoom: zoom)
		geometryStreamer.updateLodLevel()
		geometryStreamer.updateStreaming()
		
		idleIfStill(willRender: needsRender, frameCount: controller.framesDisplayed)
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.0, 0.1, 0.6, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		let visibleRegions = AppDelegate.sharedUIState.visibleRegionHashes
		regionRenderer.renderWorld(visibleSet: visibleRegions, inProjection: modelViewProjectionMatrix)
		poiRenderer.renderWorld(visibleSet: visibleRegions, inProjection: modelViewProjectionMatrix)
		effectRenderer.renderWorld(inProjection: modelViewProjectionMatrix)
		selectionRenderer.renderSelection(inProjection: modelViewProjectionMatrix)
		labelView.renderLabels(projection: mapToView)
		
		needsRender = false
//		DebugRenderer.shared.renderMarkers(inProjection: modelViewProjectionMatrix)
	}
	
	func idleIfStill(willRender: Bool, frameCount: Int) {
		needsRender = effectRenderer.animating ? true : willRender
		needsRender = geometryStreamer.streaming ? true : willRender
		if (needsRender) {
			lastRenderFrame = frameCount
		} else if frameCount - lastRenderFrame > 30 {
			self.isPaused = true
		}
	}
}

extension MapViewController : UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return dummyView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		zoom = Float(scrollView.zoomScale)
		if let renderer = poiRenderer {
			renderer.updateZoomThreshold(viewZoom: zoom)
		}
		if let streamer = geometryStreamer {
			streamer.zoomedTo(zoom)
		}
		
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
		needsRender = true
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		offset = scrollView.contentOffset
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
		needsRender = true
	}
	
	func visibleLongLat(viewBounds: CGRect) -> Aabb {
		let focusBox = viewBounds // .insetBy(dx: 100.0, dy: 100.0)
		let bottomLeft = CGPoint(x: focusBox.minX, y: focusBox.minY)
		let topRight = CGPoint(x: focusBox.maxX, y: focusBox.maxY)
		let worldCorners = [bottomLeft, topRight].map({ (p: CGPoint) -> CGPoint in
			let viewP = view.convert(p, to: dummyView)
			return mapPoint(viewP,
											from: dummyView.bounds,
											to: mapFrame,
											space: mapSpace)
		})
		return Aabb(loX: Float(worldCorners[0].x),
								loY: Float(worldCorners[1].y),
								hiX: Float(worldCorners[1].x),
								hiY: Float(worldCorners[0].y))
	}
	
	var mapToView: ((Vertex) -> CGPoint) {
		return { (p: Vertex) -> CGPoint in
			let mp = projectPoint(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)),
														 from: self.dummyView.bounds,
														 to: self.mapFrame,
														 space: self.mapSpace)
			return self.view.convert(mp, from: self.dummyView)
		}
	}
}
