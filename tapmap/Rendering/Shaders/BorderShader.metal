//
//  BorderShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-04.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
	float scaleWidth;
	float4 color;
};

struct ScaleVertex {
	float2 position;
	float2 normal;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut borderVertex(const device ScaleVertex* vertexArray [[ buffer(0) ]],
															constant FrameUniforms *frame [[ buffer(1) ]],
															unsigned int vid [[ vertex_id ]]) {
	ScaleVertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	float2 rib = v.normal * frame->scaleWidth;
	outVertex.position = frame->modelViewProjectionMatrix * float4(v.position + rib, 0.0, 1.0);
	outVertex.color = frame->color;
	return outVertex;
}

fragment float4 borderFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}
