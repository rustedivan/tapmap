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
	
	var zoom: CGFloat = 1.0
	var offset: CGPoint = .zero
	
	var geoWorld: GeoWorld!
	var mapRenderer: MapRenderer!
	
	var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
	
	var context: EAGLContext? = nil
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let path = Bundle.main.path(forResource: "countries", ofType: "geo")!
		
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
		
		scrollView.contentSize = view.frame.size
		scrollView.zoomScale = 1.0
		
		delegate = self
		
		EAGLContext.setCurrent(self.context)
		mapRenderer = MapRenderer(withGeoWorld: geoWorld)
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
	
	// MARK: - GLKView and GLKViewController delegate methods
	func glkViewControllerUpdate(_ controller: GLKViewController) {
		let viewSize = scrollView.bounds.size
		let mapSize = CGSize(width: 360.0, height: 160.0)
		
		let projectionMatrix = GLKMatrix4MakeOrtho(Float(-mapSize.width) / 2.0, Float(mapSize.width) / 2.0,
																							 Float(-mapSize.height) / 2.0, Float(mapSize.height) / 2.0,
																							 0.1, 2.0)
		let lng = offset.x * (mapSize.width / viewSize.width) / zoom
		let lat = offset.y * (mapSize.height / viewSize.height) / zoom
		
//		print("Framing \(-offset.x) : \(offset.y) @ \(zoom)")
		
		// Compute the model view matrix for the object rendered with GLKit
		var modelViewMatrix = GLKMatrix4MakeScale(Float(zoom), Float(zoom), 1.0)
		modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, Float(-lng), Float(lat), -1.5)
		modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.0, 0.1, 0.6, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		mapRenderer.renderWorld(geoWorld: geoWorld, inProjection: modelViewProjectionMatrix)
	}
}

extension MapViewController : UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return view
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		zoom = scrollView.zoomScale
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		offset = scrollView.contentOffset
	}
}
