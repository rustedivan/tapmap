//
//  PostProcessingShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2022-08-07.
//  Copyright © 2022 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
	float2 screenSize;
};

struct TexturedVertex {
	float2 position;
	float2 uv;
};

struct VertexOut {
	float4 position [[position]];
	float2 uv;
};

vertex VertexOut texturedVertex(const device TexturedVertex* vertexArray [[ buffer(0) ]],
																constant FrameUniforms* frame [[ buffer(1) ]],
																unsigned int vid [[ vertex_id ]]) {
	TexturedVertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	float2 p = v.position * frame->screenSize;
	outVertex.position = frame->modelViewProjectionMatrix * float4(p, 0.0, 1.0);
	outVertex.uv = v.uv;
	return outVertex;
}

fragment float4 chromaticAberrationFragment(VertexOut interpolated [[ stage_in ]], texture2d<float> offscreenTexture [[texture(0)]]) {
	constexpr sampler offscreen(coord::normalized, address::clamp_to_zero, filter::linear, mip_filter::linear);
	float4 color = offscreenTexture.sample(offscreen, interpolated.uv);
	return float4(color);
}

