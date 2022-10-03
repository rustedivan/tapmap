//
//  InstancedBevelJoinShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2022-10-02.
//  Copyright © 2022 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
	float width;
	float alignmentIn;
	float alignmentOut;
	float4 color;
};

struct Vertex {
	float2 position;
};

struct InstanceUniform {
	float2 a;	// preceding vertex
	float2 b;	// current vertex
	float2 c;	// subsequent vertex
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut bevelVertex(const device Vertex* vertexArray [[ buffer(0) ]],
														 constant FrameUniforms *frame [[ buffer(1) ]],
														 constant InstanceUniform *instanceUniforms [[ buffer(2) ]],
														 unsigned int vid [[ vertex_id ]],
														 unsigned int iid [[ instance_id ]]) {
	Vertex v = vertexArray[vid];
	float2 a = instanceUniforms[iid].a;
	float2 b = instanceUniforms[iid].b;
	float2 c = instanceUniforms[iid].c;
	
	float2 tangentAtB = normalize(normalize(c - b) + normalize(b - a));
	float2 normalAtB = float2(-tangentAtB.y, tangentAtB.x);
	
	// Both these vectors point toward B, instead of along the line
	float2 prevSegment = b - a;
	float2 nextSegment = b - c;
	float direction = sign(dot(prevSegment + nextSegment, normalAtB));
	
	// Since nextSegment points "backward", flip the normal
	float2 prevNormal = normalize(float2(-prevSegment.y, prevSegment.x));
	float2 nextNormal = -normalize(float2(-nextSegment.y, nextSegment.x));
	
	float alignment = direction * (direction < 0.0 ? frame->alignmentOut : frame->alignmentIn);
	float2 p0 = alignment * frame->width * (direction < 0.0 ? prevNormal : nextNormal);
	float2 p1 = alignment * frame->width * (direction < 0.0 ? nextNormal : prevNormal);
	
	float2 p = b + v.position.x * p0 + v.position.y * p1;
	VertexOut outVertex = VertexOut();
	outVertex.position = frame->modelViewProjectionMatrix * float4(p, 0.0, 1.0);
	outVertex.color = frame->color;
	return outVertex;
}

fragment float4 bevelFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}
