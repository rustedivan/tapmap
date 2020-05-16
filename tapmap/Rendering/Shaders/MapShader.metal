//
//  MapShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-03.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
};

struct InstanceUniforms {
	float4 color;
};

struct Vertex {
	float2 position;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut mapVertex(const device Vertex* vertexArray [[ buffer(0) ]],
													 constant FrameUniforms* frame [[ buffer(1) ]],
													 const device InstanceUniforms* region [[ buffer(2) ]],
													 unsigned int vid [[ vertex_id ]]) {
	Vertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	outVertex.position = frame->modelViewProjectionMatrix * float4(v.position, 0.0, 1.0);
	outVertex.color = region->color;
	return outVertex;
}

fragment float4 mapFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}
