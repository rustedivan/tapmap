//
//  Shader.fsh
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
