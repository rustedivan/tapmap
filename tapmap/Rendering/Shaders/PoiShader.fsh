//
//  PoiShader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2019-02-10.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

varying lowp vec4 colorVarying;
uniform lowp float rankThreshold;

void main()
{
	gl_FragColor = colorVarying;
}
