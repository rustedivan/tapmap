//
//  PickShader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

varying lowp float colorId;

void main()
{
    gl_FragColor = vec4(colorId, 0.0, 0.0, 1.0);
}
