//
//  PoiShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-05.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
	float threshold;
	float baseSize;
};

struct InstanceUniform {
	float2 position;
	float progress;
};

struct Vertex {
	float2 position;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut poiVertex(const device Vertex* vertexArray [[ buffer(0) ]],
													 constant FrameUniforms *frame [[ buffer(1) ]],
													 const device InstanceUniform *pois [[ buffer(2) ]],
													 unsigned int vid [[ vertex_id ]],
													 unsigned int iid [[ instance_id ]]) {
	Vertex v = vertexArray[vid];
	float2 p = pois[iid].position;
	float a = pois[iid].progress;
	
	VertexOut outVertex = VertexOut();
	outVertex.position = frame->modelViewProjectionMatrix * float4(p + v.position * frame->baseSize, 0.0, 1.0);
	outVertex.color = float4(1.0, 1.0, 1.0, a);
	return outVertex;
}

fragment float4 poiFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}

//fragment float4 poiFragment(VertexOut interpolated [[ stage_in ]], texture2d<float> markerAtlas [[texture(0)]]) {
//	constexpr sampler markers(coord::normalized, address::clamp_to_zero, filter::linear, mip_filter::linear);
//	float4 color = markerAtlas.sample(markers, interpolated.uv);
//	color.a *= interpolated.color.a;
//	return float4(color);
//}

