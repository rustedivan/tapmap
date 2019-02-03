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
	var dummyView: UIView!
	
	// Navigation
	var zoom: Float = 1.0
	var offset: CGPoint = .zero
	let mapSpace = CGRect(x: -180.0, y: -80.0, width: 360.0, height: 160.0)
	
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
		
		delegate = self
		
		EAGLContext.setCurrent(self.context)
		mapRenderer = MapRenderer(withGeoWorld: geoWorld)!
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
													to: mapSpace)
			mapP.y = -mapP.y
			
			let userState = AppDelegate.sharedUserState
			
			GeometryCounters.begin()
			defer { GeometryCounters.end() }
			
			// First split box-collided continents into open and closed sets
			let candidateContinents = geoWorld.continents.filter { aabbHitTest(p: mapP, in: $0.geography) }
			let openCandidateContinents = candidateContinents.filter { userState.regionOpened(r: $0.geography) }
			let closedCandidateContinents = candidateContinents.subtracting(openCandidateContinents)
			
			// Form array of box-collided countries in the opened continents, and split into opened/closed sets
			let candidateCountries = Set(openCandidateContinents.flatMap { $0.countries })
																													.filter { aabbHitTest(p: mapP, in: $0.geography) }
			let openCandidateCountries = candidateCountries.filter { userState.regionOpened(r: $0.geography) }
			let closedCandidateCountries = candidateCountries.subtracting(openCandidateCountries)
			
			// Finally form a list of box-collided regions of opened countries
			let candidateRegions = Set(openCandidateCountries.flatMap { $0.regions })
																											.filter { aabbHitTest(p: mapP, in: $0) }
			let openCandidateRegions = candidateRegions.filter { userState.regionOpened(r: $0) }
			let closedCandidateRegions = candidateRegions.subtracting(openCandidateRegions)
			
			// Now we have three sets of closed geographies that we could open
			var candidateGeographies: Set<GeoRegion> = []
			candidateGeographies.formUnion(closedCandidateContinents.map { $0.geography })
			candidateGeographies.formUnion(closedCandidateCountries.map { $0.geography })
			candidateGeographies.formUnion(closedCandidateRegions)
			
			if let hitRegion = pickFromRegions(p: mapP, regions: candidateGeographies) {
				placeName.text = hitRegion.name
				userState.openRegion(hitRegion)
				
				if let hitContinent = closedCandidateContinents.first(where: { $0.name == hitRegion.name }) {
					mapRenderer.updatePrimitives(forGeography: hitContinent.geography,
																			 withSubregions: Set(hitContinent.countries.map { $0.geography }))
				} else if let hitCountry = closedCandidateCountries.first(where: { $0.name == hitRegion.name }) {
					mapRenderer.updatePrimitives(forGeography: hitCountry.geography,
																			 withSubregions: hitCountry.regions)
				}
				
			}
		}
	}
	
	func pickFromRegions(p: CGPoint, regions: Set<GeoRegion>) -> GeoRegion? {
		for region in regions {
			if triangleSoupHitTest(point: p, inVertices: region.geometry.vertices, inIndices: region.geometry.indices) {
				return region
			}
		}
		return nil
	}

	// MARK: - GLKView and GLKViewController delegate methods
	func glkViewControllerUpdate(_ controller: GLKViewController) {
		modelViewProjectionMatrix = buildProjectionMatrix(viewSize: scrollView.bounds.size,
																											mapSize: mapSpace.size,
																											centeredOn: offset,
																											zoomedTo: zoom)
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.0, 0.1, 0.6, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		mapRenderer.renderWorld(geoWorld: geoWorld, inProjection: modelViewProjectionMatrix)
	}
}

extension MapViewController : UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return dummyView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		zoom = Float(scrollView.zoomScale)
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		offset = scrollView.contentOffset
	}
}
