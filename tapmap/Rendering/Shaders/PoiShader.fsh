//
//  PoiShader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

varying lowp vec4 colorVarying;
varying lowp float rank;
uniform lowp float rankThreshold;

void main()
{
	if (rank > rankThreshold) {
		discard;
	}
  gl_FragColor = colorVarying;
}
