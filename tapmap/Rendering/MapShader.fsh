//
//  MapShader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

varying mediump vec4 colorVar;
void main()
{
	gl_FragColor.rgb = colorVar.rgb;
}
