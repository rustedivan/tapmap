//
//  SelectionShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-06.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
	float width;
	float4 color;
};

struct Vertex {
	float2 position;
};

struct InstanceUniform {
	float2 a;
	float2 b;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut selectionVertex(const device Vertex* vertexArray [[ buffer(0) ]],
																 constant FrameUniforms *frame [[ buffer(1) ]],
																 constant InstanceUniform *instanceUniforms [[ buffer(2) ]],
																 unsigned int vid [[ vertex_id ]],
																 unsigned int iid [[ instance_id ]]) {
	Vertex v = vertexArray[vid];
	float2 a = instanceUniforms[iid].a;
	float2 b = instanceUniforms[iid].b;
	float2 spine = b - a;
	float2 rib = normalize(float2(-spine.y, spine.x));
	float2 p = a + (v.position.x * spine) +
								 (v.position.y * rib) * frame->width;
	VertexOut outVertex = VertexOut();
	outVertex.position = frame->modelViewProjectionMatrix * float4(p, 0.0, 1.0);
	outVertex.color = frame->color;
	return outVertex;
}

fragment float4 selectionFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}

