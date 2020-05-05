//
//  PoiShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-05.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct PoiUniforms {
	float4x4 modelViewProjectionMatrix;
	float threshold;
	float baseSize;
	float progress;
};

struct ScaleVertex {
	float2 position;
	float2 normal;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut poiVertex(const device ScaleVertex* vertexArray [[ buffer(0) ]],
															constant PoiUniforms *uniforms [[ buffer(1) ]],
															unsigned int vid [[ vertex_id ]]) {
	ScaleVertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	float2 rib = v.normal * uniforms->baseSize;
	outVertex.position = uniforms->modelViewProjectionMatrix * float4(v.position + rib, 0.0, 1.0);
	outVertex.color = float4(1.0, 1.0, 1.0, uniforms->progress);
	return outVertex;
}

fragment float4 poiFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}

