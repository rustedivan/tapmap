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
uniform mat4 scaleInPlaceMatrix;
uniform vec4 regionColor;
uniform mediump float progress;

void main()
{
	colorVar = regionColor;
	gl_Position = modelViewProjectionMatrix * scaleInPlaceMatrix * position;
}
