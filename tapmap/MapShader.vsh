//
//  MapShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;
attribute vec4 barycentric;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
uniform lowp vec4 regionColor;

void main()
{
		colorVarying = barycentric;
    gl_Position = modelViewProjectionMatrix * position;
}
