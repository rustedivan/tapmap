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

struct InstanceUniforms {
	float progress;
};

struct ScaleVertex {
	float2 position;
	float2 normal;
};

struct VertexOut {
	float4 position [[position]];
	float2 uv;
	float4 color;
};

vertex VertexOut poiVertex(const device ScaleVertex* vertexArray [[ buffer(0) ]],
													 constant FrameUniforms *frame [[ buffer(1) ]],
													 const device InstanceUniforms *poi [[ buffer(2) ]],
													 unsigned int vid [[ vertex_id ]]) {
	ScaleVertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	float2 rib = v.normal * frame->baseSize;
	outVertex.position = frame->modelViewProjectionMatrix * float4(v.position + rib, 0.0, 1.0);
	outVertex.color = float4(1.0, 1.0, 1.0, poi->progress);
	outVertex.uv = float2((v.normal.x > 0.0) * 0.25, (v.normal.y < 0.0) * 1.00);
	return outVertex;
}

fragment float4 poiFragment(VertexOut interpolated [[ stage_in ]], texture2d<float> markerAtlas [[texture(0)]]) {
	constexpr sampler markers(coord::normalized, address::clamp_to_zero, filter::linear, mip_filter::linear);
	float4 color = markerAtlas.sample(markers, interpolated.uv);
	color.a *= interpolated.color.a;
	return float4(color);
}

