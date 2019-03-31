//
//  OpeningShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2019-03-24.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;

varying mediump vec4 colorVar;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 center;
uniform lowp vec4 regionColor;
uniform lowp float progress;

void main()
{
	float scale = 1.0 + progress * 0.25;
	colorVar = regionColor;
	vec4 scaledPosition = (position - center) * scale + center;
	gl_Position = modelViewProjectionMatrix * scaledPosition;
}
