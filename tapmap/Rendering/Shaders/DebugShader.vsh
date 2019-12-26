//
//  MapShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;
varying mediump vec4 colorVar;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 markerColor;

void main()
{
		colorVar = markerColor;
		gl_Position = modelViewProjectionMatrix * position;
}
