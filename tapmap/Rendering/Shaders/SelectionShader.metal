//
//  SelectionShader.metal
//  tapmap
//
//  Created by Ivan Milles on 2020-05-06.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct SelectionUniforms {
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

vertex VertexOut selectionVertex(const device ScaleVertex* vertexArray [[ buffer(0) ]],
																 constant SelectionUniforms *uniforms [[ buffer(1) ]],
																 unsigned int vid [[ vertex_id ]]) {
	ScaleVertex v = vertexArray[vid];
	VertexOut outVertex = VertexOut();
	float2 rib = v.normal * uniforms->scaleWidth;
	outVertex.position = uniforms->modelViewProjectionMatrix * float4(v.position + rib, 0.0, 1.0);
	outVertex.color = uniforms->color;
	return outVertex;
}

fragment float4 selectionFragment(VertexOut interpolated [[ stage_in ]]) {
	return float4(interpolated.color);
}

