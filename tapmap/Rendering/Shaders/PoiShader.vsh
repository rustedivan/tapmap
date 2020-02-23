//
//  MapShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

attribute vec4 position;
attribute vec2 normal;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 poiColor;
uniform lowp float progress;
uniform lowp float baseSize;

void main()
{
		colorVarying = vec4(poiColor.xyz, progress);
		gl_Position = modelViewProjectionMatrix * (position + vec4(normal, 0.0, 0.0) * baseSize);
}
