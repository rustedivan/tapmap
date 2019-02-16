//
//  MapGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-06-19.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry
import GLKit

func mapPoint(_ p: CGPoint, from a: CGRect, to b: CGRect) -> CGPoint {
	let u = (b.width) * (p.x - a.minX) / (a.width) + b.minX
	let v = (b.height) * (p.y - a.minY) / (a.height) + b.minY
	return CGPoint(x: u, y: v)
}

func buildProjectionMatrix(viewSize: CGSize, mapSize: CGSize, centeredOn center: CGPoint, zoomedTo zoom: Float) -> GLKMatrix4 {
	let projectionMatrix = GLKMatrix4MakeOrtho(0.0, Float(mapSize.width),
																						 Float(mapSize.height), 0.0,
																						 0.1, 2.0)
	let lng = Float((center.x / viewSize.width) * mapSize.width)
	let lat = Float((center.y / viewSize.height) * mapSize.height)
	let lngOffset = Float(mapSize.width / 2.0)
	let latOffset = Float(mapSize.height / 2.0)
	
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
	
	return GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
}
