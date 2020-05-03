//
//  MapGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-06-19.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry
import GLKit.GLKMatrix4

// Map from screen space to map space
func mapPoint(_ p: CGPoint, from view: CGRect, to subView: CGRect, space: CGRect) -> CGPoint {
	let x = p.x - view.minX - subView.minX
	let y = p.y - view.minY - subView.minY
	
	let u = (x / subView.width) * space.width + space.minX
	let v = (y / subView.height) * space.height + space.minY

	return CGPoint(x: u, y: -v)	// Flip Y axis
}

// Project from map space to screen space (mapPoint, in reverse)
func projectPoint(_ m: CGPoint, from view: CGRect, to subView: CGRect, space: CGRect) -> CGPoint {
	let mp = CGPoint(x: m.x, y: -m.y)	// Flip Y axis
	let x = (mp.x - space.minX) * (subView.width / space.width)
	let y = (mp.y - space.minY) * (subView.height / space.height)
	return CGPoint(x: x + subView.minX + view.minX,
								 y: y + subView.minY + view.minY)
}

func buildProjectionMatrix(viewSize: CGSize, mapSize: CGSize, centeredOn center: CGPoint, zoomedTo zoom: Float) -> simd_float4x4 {
	let viewAspect = viewSize.height / viewSize.width
	let fittedMapSize = CGSize(width: mapSize.width, height: mapSize.width * viewAspect)
	let projectionMatrix = GLKMatrix4MakeOrtho(0.0, Float(fittedMapSize.width),
																						 Float(fittedMapSize.height), 0.0,
																						 0.1, 2.0)
	let lng = Float((center.x / viewSize.width) * fittedMapSize.width)
	let lat = Float((center.y / viewSize.height) * fittedMapSize.height)
	let lngOffset = Float(fittedMapSize.width / 2.0)
	let latOffset = Float(fittedMapSize.height / 2.0)
	
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
	
	let out = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)

	//	matrix_multiply(<#T##__x: simd_float4x4##simd_float4x4#>, <#T##__y: simd_float4x4##simd_float4x4#>)
	return simd_float4x4(columns: (SIMD4<Float>(x: out.m00, y: out.m01, z: out.m02, w: out.m03),
																 SIMD4<Float>(x: out.m10, y: out.m11, z: out.m12, w: out.m13),
																 SIMD4<Float>(x: out.m20, y: out.m21, z: out.m22, w: out.m23),
																 SIMD4<Float>(x: out.m30, y: out.m31, z: out.m32, w: out.m33)))
}

func mapZoomLimits(viewSize: CGSize, mapSize: CGSize) -> (CGFloat, CGFloat) {
	let height = viewSize.height / UIScreen.main.scale
	return (height / mapSize.height, 50.0)
}
