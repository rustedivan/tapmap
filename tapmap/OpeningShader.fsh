//
//  OpeningShader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2019-03-24.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

uniform lowp float progress;

varying mediump vec4 colorVar;

void main()
{
	gl_FragColor.rgba = colorVar * (1.0 - progress);
}
