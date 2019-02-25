//
//  MapShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;
attribute vec4 barycentric;

varying mediump vec4 colorVar;
varying mediump vec4 barycentricVar;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 regionColor;

void main()
{
		colorVar = regionColor;
		barycentricVar = barycentric;
    gl_Position = modelViewProjectionMatrix * position;
}
