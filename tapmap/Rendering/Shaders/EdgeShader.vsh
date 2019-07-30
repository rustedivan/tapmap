//
//  MapShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;
attribute vec2 miter;

varying mediump vec4 colorVar;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 edgeColor;
uniform lowp float edgeWidth;

void main()
{
		colorVar = edgeColor;
		gl_Position = modelViewProjectionMatrix * (position + vec4(miter, 0.0, 0.0) * edgeWidth);
}
