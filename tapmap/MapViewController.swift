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
		
		dummyView = UIView(frame: view.frame)
		scrollView.contentSize = dummyView.frame.size
		scrollView.addSubview(dummyView)
		
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
		let projectionMatrix = GLKMatrix4MakeOrtho(0.0, Float(mapSpace.width),
																							 Float(mapSpace.height), 0.0,
																							 0.1, 2.0)
		let lng = Float((offset.x / viewSize.width) * mapSpace.width)
		let lat = Float((offset.y / viewSize.height) * mapSpace.height)
		let lngOffset = Float(mapSpace.width / 2.0)
		let latOffset = Float(mapSpace.height / 2.0)
		
		// Compute the model view matrix for the object rendered with GLKit
		// (Z = -1.0 to position between the clipping planes)
		var modelViewMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, -1.0)
		
		// Matrix operations, applied in reverse order
		// 3: Move to scaled UIScrollView content offset
		modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, -lng, -lat, 0.0)
		// 2: Scale the data and flip the Y axis
		modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, zoom, -zoom, 1.0)
		// 1: Center the data
		modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, lngOffset, -latOffset, 0.0)
		
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
		return dummyView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		zoom = Float(scrollView.zoomScale)
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		offset = scrollView.contentOffset
	}
}