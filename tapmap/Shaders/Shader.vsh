//
//  Shader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;

void main()
{
	colorVarying = vec4(0.5, 0.5, 0.9, 0.9);
	
    gl_Position = modelViewProjectionMatrix * position;
}
