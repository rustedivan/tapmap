//
//  MapGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-06-19.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import Foundation
import CoreGraphics.CGGeometry

func mapPoint(_ p: CGPoint, from a: CGRect, to b: CGRect) -> CGPoint {
	let u = (b.width) * (p.x - a.minX) / (a.width) + b.minX
	let v = (b.height) * (p.y - a.minY) / (a.height) + b.minY
	return CGPoint(x: u, y: v)
}

func aabbHitTest(p: CGPoint, in region: GeoRegion) -> Bool{
	let aabb = region.geometry.aabb
	
	// $ Replace aabb with CGRect directly.
	let rect = CGRect(x: Double(aabb.minX), y: Double(aabb.minY), width: Double(aabb.maxX - aabb.minX), height: Double(aabb.maxY - aabb.minY))
	return rect.contains(p)
}
