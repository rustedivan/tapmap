//
//  MapShader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

#extension GL_OES_standard_derivatives: enable

varying mediump vec4 colorVar;
varying mediump vec4 barycentricVar;

mediump float edgeWidth = 1.0;

// Via Florian Boesch @ codeflow.org
mediump float edgeSelect() {
	mediump vec3 mipSlope = fwidth(barycentricVar.xyz) * edgeWidth;
	mediump vec3 distancesToEdges = smoothstep(vec3(0.0), mipSlope, barycentricVar.xyz);
	return min(min(distancesToEdges.x, distancesToEdges.y), distancesToEdges.z);
}

void main()
{
	gl_FragColor.rgb = mix(vec3(0.0), colorVar.rgb, edgeSelect());
}
