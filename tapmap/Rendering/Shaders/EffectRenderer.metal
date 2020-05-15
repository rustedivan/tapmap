//
//  EffectRenderer.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-07.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
	float4x4 modelViewProjectionMatrix;
};

struct InstanceUniforms {
	float progress;
	float4x4 scaleInPlaceMatrix;
	float4 color;
};

struct Vertex {
	float2 position;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut effectVertex(const device Vertex* vertexArray [[ buffer(0) ]],
															constant FrameUniforms* frame [[ buffer(1) ]],
															const device InstanceUniforms* effect [[ buffer(2) ]],
															unsigned int vid [[ vertex_id ]]) {
	Vertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	outVertex.position = frame->modelViewProjectionMatrix * effect->scaleInPlaceMatrix * float4(v.position, 0.0, 1.0);
	outVertex.color = effect->color * (1.0 - effect->progress);
	return outVertex;
}

fragment float4 effectFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}
