//
//  GameViewController.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-03-31.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import MetalKit

class MapViewController: UIViewController, MTKViewDelegate {
	@IBOutlet weak var metalView: MTKView!
	@IBOutlet var scrollView: UIScrollView!
	@IBOutlet var placeName: UILabel!
	@IBOutlet var labelView: LabelView!
	
	var renderers: MetalRenderer!
	
	// Presentation
	var world: RuntimeWorld
	var dummyView: UIView!
	
	// Navigation
	var zoom: Float = 1.0
	var offset: CGPoint = .zero
	let mapSpace = CGRect(x: -180.0, y: -80.0, width: 360.0, height: 160.0)
	var mapFrame = CGRect.zero
	var lastRenderFrame: Int = Int.max
	var needsRender: Bool = true { didSet {
		if needsRender { metalView.isPaused = false }
	}}
	
	// Rendering
	var geometryStreamer: GeometryStreamer
	
	required init?(coder: NSCoder) {
		let path = Bundle.main.path(forResource: "world", ofType: "geo")!
		guard let streamer = GeometryStreamer(attachFile: path) else {
			print("Could not attach geometry streamer to \(path)")
			return nil
		}
		self.geometryStreamer = streamer
		
		let geoWorld = geometryStreamer.loadGeoWorld()
		let worldTree = geometryStreamer.loadWorldTree()
		world = RuntimeWorld(withGeoWorld: geoWorld)
		
		let userState = AppDelegate.sharedUserState
		let uiState = AppDelegate.sharedUIState
		
		userState.delegate = world
		userState.buildWorldAvailability(withWorld: world)
		uiState.delegate = world
		uiState.buildQuadTree(withTree: worldTree)
		
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let metalView = view as! MTKView
		renderers = MetalRenderer(in: metalView, forWorld: world)
		geometryStreamer.metalDevice = renderers.device
		metalView.delegate = self
		
		// Scroll view setup
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
		
		labelView.buildPoiPrimitives(withVisibleContinents: world.availableContinents,
																 countries: world.availableCountries,
																 provinces: world.availableProvinces)
		
		// Prepare UI for rendering the map
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
		needsRender = true
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
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
			let candidateContinents = Set(world.visibleContinents.filter { boxContains($0.value.aabb, tapPoint) }.values)
			let candidateCountries = Set(world.visibleCountries.filter { boxContains($0.value.aabb, tapPoint) }.values)
			let candidateRegions = Set(world.visibleProvinces.filter { boxContains($0.value.aabb, tapPoint) }.values)

			if let hitHash = pickFromTessellations(p: tapPoint, candidates: candidateContinents) {
				let hitContinent = world.availableContinents[hitHash]!
				if processSelection(of: hitContinent, user: userState, ui: uiState) {
					processVisit(of: hitContinent, user: userState, ui: uiState)
				}
			} else if let hitHash = pickFromTessellations(p: tapPoint, candidates: candidateCountries) {
				let hitCountry = world.availableCountries[hitHash]!
				if processSelection(of: hitCountry, user: userState, ui: uiState) {
					processVisit(of: hitCountry, user: userState, ui: uiState)
				}
			} else if let hitHash = pickFromTessellations(p: tapPoint, candidates: candidateRegions) {
				let hitRegion = world.availableProvinces[hitHash]!
				_ = processSelection(of: hitRegion, user: userState, ui: uiState)
			} else {
				uiState.clearSelection()
				renderers.selectionRenderer.clear()
			}
			
			uiState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
		}
	}
	
	func processSelection<T:GeoIdentifiable>(of hit: T, user: UserState, ui: UIState) -> Bool {
		placeName.text = hit.name
		if ui.selected(hit) {
			user.visitPlace(hit)
			return true
		} else {
			ui.selectRegion(hit)
			renderers.selectionRenderer.updatePrimitive(selectedRegionHash: hit.geographyId.hashed)
			return false
		}
	}
	
	func processVisit<T:GeoNode & GeoPlaceContainer>(of hit: T, user: UserState, ui: UIState)
		where T.SubType: GeoPlaceContainer {

		user.openPlace(hit)
		renderers.selectionRenderer.clear()
		
		if geometryStreamer.renderPrimitive(for: hit.geographyId.hashed) != nil {
			renderers.effectRenderer.addOpeningEffect(for: hit.geographyId.hashed)
			geometryStreamer.evictPrimitive(for: hit.geographyId.hashed)
		}

		renderers.poiRenderer.updatePrimitives(for: hit, with: hit.children)
		labelView.updatePrimitives(for: hit, with: hit.children)
	}

	func prepareFrame() {
		renderers.updateProjection(viewSize: scrollView.bounds.size,
																	 mapSize: mapSpace.size,
																	 centeredOn: offset,
																	 zoomedTo: zoom)
		renderers.prepareFrame(forWorld: world)
		
//		labelView.updateLabels(for: metalRenderer.poiRenderer.activePoiHashes,
//													 inArea: visibleLongLat(viewBounds: view.bounds),
//													 atZoom: zoom)
		
		geometryStreamer.updateLodLevel()	// Must run after requests have been filed in renderers.prepareFrame, otherwise glitch when switching LOD level
		geometryStreamer.updateStreaming()
		
		needsRender = geometryStreamer.streaming ? true : needsRender

		if renderers.shouldIdle(appUpdated: needsRender) {
			metalView.isPaused = true
		}
	}
	
	func draw(in view: MTKView) {
		prepareFrame()
		
		guard let drawable = view.currentDrawable else { fatalError("No drawable") }
		renderers.render(forWorld: world, into: drawable)
//		labelView.renderLabels(projection: mapToView)

		needsRender = false
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		renderers.updateProjection(viewSize: size,
																	 mapSize: mapSpace.size,
																	 centeredOn: offset,
																	 zoomedTo: zoom)
  }
}

extension MapViewController : UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return dummyView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		zoom = Float(scrollView.zoomScale)
		
		geometryStreamer.zoomedTo(zoom)
		renderers.zoomLevel = zoom

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
