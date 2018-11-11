//
//  PickShader.vsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

attribute vec4 position;

varying lowp float colorId;

uniform mat4 modelViewProjectionMatrix;
uniform lowp float pickingId;

void main()
{
		colorId = pickingId;
    gl_Position = modelViewProjectionMatrix * position;
}
