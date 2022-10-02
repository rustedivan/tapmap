//
//  InstanceBasedLineUtils.swift
//  tapmap
//
//  Created by Ivan Milles on 2022-10-02.
//  Copyright © 2022 Wildbrain. All rights reserved.
//

import Metal
import simd

struct LineInstanceUniforms {
	var a: simd_float2
	var b: simd_float2
}

typealias LineSegmentPrimitive = RenderPrimitive

func makeLineSegmentPrimitive(in device: MTLDevice, inside: Float, outside: Float) -> LineSegmentPrimitive {
	let vertices: [Vertex] = [
		Vertex(0.0, -inside),
		Vertex(1.0, -inside),
		Vertex(1.0,  outside),
		Vertex(0.0,  outside)
	]
	let indices: [UInt16] = [
		0, 1, 2, 0, 2, 3
	]
	
	return LineSegmentPrimitive(	polygons: [vertices],
																indices: [indices],
																drawMode: .triangle,
																device: device,
																color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0),
																ownerHash: 0,
																debugName: "Line segment primitive")
}

func generateContourCollectionGeometry(contours: [VertexRing]) -> Array<LineInstanceUniforms> {
	let segmentCount = contours.reduce(0) { $0 + $1.vertices.count }
	var vertices = Array<LineInstanceUniforms>()
	vertices.reserveCapacity(segmentCount)
	for contour in contours {
		for i in 0..<contour.vertices.count - 1 {
			let a = contour.vertices[i]
			let b = contour.vertices[i + 1]
			vertices.append(LineInstanceUniforms(
				a: simd_float2(x: a.x, y: a.y),
				b: simd_float2(x: b.x, y: b.y)
			))
		}
	}
	return vertices
}
