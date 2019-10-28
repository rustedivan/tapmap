//
//  MapShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

attribute vec4 position;
attribute float scalar;

varying lowp vec4 colorVarying;
varying lowp float rank;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 poiColor;

void main()
{
		colorVarying = poiColor;
		rank = scalar;
		gl_Position = modelViewProjectionMatrix * position;
}
