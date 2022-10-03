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

struct JoinInstanceUniforms {
	var a: simd_float2
	var b: simd_float2
	var c: simd_float2
}

typealias LineSegmentPrimitive = RenderPrimitive
typealias JoinSegmentPrimitive = RenderPrimitive

func makeLineSegmentPrimitive(in device: MTLDevice, inside: Float, outside: Float) -> LineSegmentPrimitive {
	let vertices: [Vertex] = [
		Vertex(0.0,  inside),
		Vertex(1.0,  inside),
		Vertex(1.0, -outside),
		Vertex(0.0, -outside)
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

func makeBevelJoinPrimitive(in device: MTLDevice, width: Float) -> JoinSegmentPrimitive {
	let vertices: [Vertex] = [
		Vertex(0.0, 0.0),
		Vertex(width, 0.0),
		Vertex(0.0, width),
	]
	let indices: [UInt16] = [
		0, 1, 2
	]
	
	return JoinSegmentPrimitive(	polygons: [vertices],
																indices: [indices],
																drawMode: .triangle,
																device: device,
																color: Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0),
																ownerHash: 0,
																debugName: "Bevel join primitive")
}

func generateContourLineGeometry(contours: [VertexRing]) -> Array<LineInstanceUniforms> {
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
		let first = contour.vertices.first!
		let last = contour.vertices.last!
		vertices.append(LineInstanceUniforms(
			a: simd_float2(last.x, last.y),
			b: simd_float2(first.x, first.y)
		))
	}
	return vertices
}

func generateContourJoinGeometry(contours: [VertexRing]) -> Array<JoinInstanceUniforms> {
	let segmentCount = contours.reduce(0) { $0 + $1.vertices.count }
	var vertices = Array<JoinInstanceUniforms>()
	vertices.reserveCapacity(segmentCount)
	for contour in contours {
		for i in 1..<contour.vertices.count - 1 {
			let a = contour.vertices[i - 1]
			let b = contour.vertices[i]
			let c = contour.vertices[i + 1]
			vertices.append(JoinInstanceUniforms(
				a: simd_float2(x: a.x, y: a.y),
				b: simd_float2(x: b.x, y: b.y),
				c: simd_float2(x: c.x, y: c.y)
			))
		}
		if vertices.count >= 3 {
			let first = contour.vertices.first!
			let second = contour.vertices[1]
			let last = contour.vertices.last!
			vertices.append(JoinInstanceUniforms(
				a: simd_float2(last.x, last.y),
				b: simd_float2(first.x, first.y),
				c: simd_float2(second.x, second.y)
			))
		}
	}
	return vertices
}
