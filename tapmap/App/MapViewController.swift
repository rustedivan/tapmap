//
//  GameViewController.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-03-31.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import GLKit
import OpenGLES

var debugCursorHandle: UUID!

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

		do {
			try self.geoWorld = PropertyListDecoder().decode(GeoWorld.self, from: geoData as Data)
			AppDelegate.sharedUIState.buildWorldTree(withWorld: self.geoWorld, userState: AppDelegate.sharedUserState)
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
		
		let zoomLimits = mapZoomLimits(viewSize: view.frame.size, mapSize: mapSpace.size)
		scrollView.minimumZoomScale = zoomLimits.0
		scrollView.zoomScale = zoomLimits.0
		scrollView.maximumZoomScale = zoomLimits.1
		
		// Calculate view-space frame of the map (scale map to fit in view, calculate the vertical offset to center it)
		let heightDiff = dummyView.bounds.height - (mapSpace.height / (mapSpace.width / dummyView.bounds.width))
		mapFrame = dummyView.bounds.insetBy(dx: 0.0, dy: heightDiff / 2.0)
		
		delegate = self
		
		EAGLContext.setCurrent(self.context)
		mapRenderer = MapRenderer(withGeoWorld: geoWorld)!
		poiRenderer = PoiRenderer(withGeoWorld: geoWorld)!
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
			var mapP = mapPoint(viewP,
													from: dummyView.bounds,
													to: mapFrame,
													space: mapSpace)
			mapP.y = -mapP.y
			
			DebugRenderer.shared.moveCursor(mapP.x, mapP.y)
			
			let userState = AppDelegate.sharedUserState
			let uiState = AppDelegate.sharedUIState
			
			GeometryCounters.begin()
			defer { GeometryCounters.end() }
			
			// First split box-collided continents into open and closed sets
			let candidateContinents = geoWorld.children.filter { aabbHitTest(p: mapP, aabb: $0.aabb) }
			let openCandidateContinents = candidateContinents.filter { userState.placeVisited($0) }
			let closedCandidateContinents = candidateContinents.subtracting(openCandidateContinents)
			
			// Form array of box-collided countries in the opened continents, and split into opened/closed sets
			let candidateCountries = Set(openCandidateContinents.flatMap { $0.children })
																													.filter { aabbHitTest(p: mapP, aabb: $0.aabb) }
			let openCandidateCountries = candidateCountries.filter { userState.placeVisited($0) }
			let closedCandidateCountries = candidateCountries.subtracting(openCandidateCountries)
			
			// Finally form a list of box-collided regions of opened countries
			let candidateRegions = Set(openCandidateCountries.flatMap { $0.children })
																											.filter { aabbHitTest(p: mapP, aabb: $0.aabb) }
			// let openCandidateRegions = candidateRegions.filter { userState.placeVisited($0) }
			// let closedCandidateRegions = candidateRegions.subtracting(openCandidateRegions)
			
			// Perform three different checks for the three different Kinds
			if let hitContinent = pickFromTessellations(p: mapP, candidates: closedCandidateContinents) {
				if uiState.selected(hitContinent) {
					userState.visitPlace(hitContinent)
					uiState.updateTree(replace: hitContinent, with: hitContinent.children)
				} else {
					uiState.selectRegion(hitContinent)
					selectionRenderer.select(geometry: hitContinent)
				}
				
				placeName.text = hitContinent.name
				
				if let toAnimate = mapRenderer.updatePrimitives(for: hitContinent, with: hitContinent.children) {
					effectRenderer.addOpeningEffect(for: toAnimate, at: hitContinent.geometry.midpoint)
				}
				poiRenderer.updatePrimitives(for: hitContinent, with: hitContinent.children)
			} else if let hitCountry = pickFromTessellations(p: mapP, candidates: closedCandidateCountries) {
				if uiState.selected(hitCountry) {
					userState.visitPlace(hitCountry)
					uiState.updateTree(replace: hitCountry, with: hitCountry.children)
				} else {
					uiState.selectRegion(hitCountry)
					selectionRenderer.select(geometry: hitCountry)
				}
				
				placeName.text = hitCountry.name
				
				if let toAnimate = mapRenderer.updatePrimitives(for: hitCountry, with: hitCountry.children) {
					effectRenderer.addOpeningEffect(for: toAnimate, at: hitCountry.geometry.midpoint)
				}
				poiRenderer.updatePrimitives(for: hitCountry, with: hitCountry.children)
			} else if let hitRegion = pickFromTessellations(p: mapP, candidates: candidateRegions) {
				if uiState.selected(hitRegion) {
					userState.visitPlace(hitRegion)
				} else {
					uiState.selectRegion(hitRegion)
					selectionRenderer.select(geometry: hitRegion)
				}
				placeName.text = hitRegion.name
			} else {
				uiState.clearSelection()
				selectionRenderer.clear()
			}
		}
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
		debugRenderTree(AppDelegate.sharedUIState.worldTree)
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.0, 0.1, 0.6, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		mapRenderer.renderWorld(geoWorld: geoWorld, inProjection: modelViewProjectionMatrix)
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
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		offset = scrollView.contentOffset
	}
}
