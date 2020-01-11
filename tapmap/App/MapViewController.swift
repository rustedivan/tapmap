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
	
	// Presentation
	var geoWorld: GeoWorld!
	var mapRenderer: MapRenderer!
	var poiRenderer: PoiRenderer!
	var effectRenderer: EffectRenderer!
	var selectionRenderer: SelectionRenderer!
	var dummyView: UIView!
	
	// Navigation
	var zoom: Float = 1.0
	var offset: CGPoint = .zero
	let mapSpace = CGRect(x: -180.0, y: -80.0, width: 360.0, height: 160.0)
	var mapFrame = CGRect.zero
	
	// Rendering
	var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
	var context: EAGLContext? = nil
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let path = Bundle.main.path(forResource: "world", ofType: "geo")!
		
		print("Starting to load geometry.")
		let startTime = Date()
		let geoData = NSData(contentsOfFile: path)!

		let userState = AppDelegate.sharedUserState
		let uiState = AppDelegate.sharedUIState
		do {
			try self.geoWorld = PropertyListDecoder().decode(GeoWorld.self, from: geoData as Data)
			userState.buildWorldAvailability(withWorld: self.geoWorld)
			uiState.buildWorldTree(withWorld: self.geoWorld, userState: AppDelegate.sharedUserState)
		} catch {
			print("Could not load world.")
			return
		}
		
		let duration = Date().timeIntervalSince(startTime)
		print("Load done in \(Int(duration)) seconds.")
		
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
		mapRenderer = MapRenderer(withVisibleContinents: userState.availableContinents,
															countries: userState.availableCountries,
															regions: userState.availableRegions)
		poiRenderer = PoiRenderer(withVisibleContinents: userState.availableContinents,
															countries: userState.availableCountries,
															regions: userState.availableRegions)
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
		if sender.state == .ended {
			let viewP = sender.location(in: dummyView)
			let mapP = mapPoint(viewP, from: dummyView.bounds, to: mapFrame, space: mapSpace)
			let tapPoint = Vertex(Float(mapP.x), Float(-mapP.y))
			
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
			
			if let hitContinent = pickFromTessellations(p: tapPoint, candidates: candidateContinents) {
				if processSelection(of: hitContinent, user: userState, ui: uiState) {
					processVisit(of: hitContinent, user: userState, ui: uiState)
				}
			} else if let hitCountry = pickFromTessellations(p: tapPoint, candidates: candidateCountries) {
				if processSelection(of: hitCountry, user: userState, ui: uiState) {
					processVisit(of: hitCountry, user: userState, ui: uiState)
				}
			} else if let hitRegion = pickFromTessellations(p: tapPoint, candidates: candidateRegions) {
				_ = processSelection(of: hitRegion, user: userState, ui: uiState)
			} else {
				uiState.clearSelection()
				selectionRenderer.clear()
			}
		}
		
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
	}
	
	func processSelection<T:GeoIdentifiable & GeoTessellated>(of hit: T, user: UserState, ui: UIState) -> Bool {
		placeName.text = hit.name
		if ui.selected(hit) {
			user.visitPlace(hit)
			return true
		} else {
			ui.selectRegion(hit)
			selectionRenderer.select(geometry: hit)
			return false
		}
	}
	
	func processVisit<T:GeoNode & GeoTessellated>(of hit: T, user: UserState, ui: UIState)
		where T.SubType: GeoPlaceContainer,
					T.SubType.PrimitiveType == ArrayedRenderPrimitive {
		user.openPlace(hit)
		ui.updateTree(replace: hit, with: hit.children)
			
		if let toAnimate = mapRenderer.updatePrimitives(for: hit, with: hit.children) {
			effectRenderer.addOpeningEffect(for: toAnimate, at: hit.geometry.midpoint)
		}
		poiRenderer.updatePrimitives(for: hit, with: hit.children)
	}

	// MARK: - GLKView and GLKViewController delegate methods
	func glkViewControllerUpdate(_ controller: GLKViewController) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: scrollView.bounds.size,
																											mapSize: mapSpace.size,
																											centeredOn: offset,
																											zoomedTo: zoom)
		effectRenderer.updatePrimitives()
		selectionRenderer.outlineWidth = 0.2 / zoom
		poiRenderer.updateFades()
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.0, 0.1, 0.6, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		let visibleRegions = AppDelegate.sharedUIState.visibleRegionHashes
		mapRenderer.renderWorld(geoWorld: geoWorld, inProjection: modelViewProjectionMatrix, visibleSet: visibleRegions)
		poiRenderer.renderWorld(geoWorld: geoWorld, inProjection: modelViewProjectionMatrix)
		effectRenderer.renderWorld(geoWorld: geoWorld, inProjection: modelViewProjectionMatrix)
		selectionRenderer.renderSelection(inProjection: modelViewProjectionMatrix)
		
		DebugRenderer.shared.renderMarkers(inProjection: modelViewProjectionMatrix)
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
		
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		offset = scrollView.contentOffset
		AppDelegate.sharedUIState.cullWorldTree(focus: visibleLongLat(viewBounds: view.bounds))
	}
	
	func visibleLongLat(viewBounds: CGRect) -> Aabb {
		let focusBox = viewBounds // .insetBy(dx: 100.0, dy: 100.0)
		let bottomLeft = CGPoint(x: focusBox.minX, y: focusBox.minY)
		let topRight = CGPoint(x: focusBox.maxX, y: focusBox.maxY)
		let worldCorners = [bottomLeft, topRight].map({ (p: CGPoint) -> CGPoint in
			let viewP = view.convert(p, to: dummyView)
			var mapP = mapPoint(viewP,
												from: dummyView.bounds,
												to: mapFrame,
												space: mapSpace)
			mapP.y = -mapP.y
			return mapP
		})
		return Aabb(loX: Float(worldCorners[0].x),
								loY: Float(worldCorners[1].y),
								hiX: Float(worldCorners[1].x),
								hiY: Float(worldCorners[0].y))
	}
}
