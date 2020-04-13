//
//  OutlineRenderPrimitive.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-07-30.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import OpenGLES

class OutlineRenderPrimitive {
	let ownerHash: Int
	
	var vertexBuffer: GLuint = 0
	let elementCounts: [GLsizei]
	
	let name: String
	
	init(contours: RegionContours, ownerHash hash: Int, debugName: String) {
		ownerHash = hash
		name = debugName
		
		guard !contours.isEmpty else { elementCounts = []; return	}
		
		// Concatenate all vertex rings into one buffer
		var vertices: [ScaleVertex] = []
		var ringLengths: [GLsizei] = []
		for ring in contours {
			guard !ring.isEmpty else { continue }
			vertices.append(contentsOf: ring)
			ringLengths.append(GLsizei(ring.count))
		}
		
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		glBufferData(GLenum(GL_ARRAY_BUFFER),
								 GLsizeiptr(MemoryLayout<ScaleVertex>.stride * vertices.count),
								 vertices,
								 GLenum(GL_STATIC_DRAW))
		
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
		elementCounts = ringLengths
		
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), vertexBuffer, 0, "\(debugName).vertices")
	}
	
	deinit {
		glDeleteBuffers(1, &vertexBuffer)
	}
}


func render(primitive: OutlineRenderPrimitive) {
	guard !primitive.elementCounts.isEmpty else {
		return
	}
	
	glEnableClientState(GLenum(GL_VERTEX_ARRAY))
	glEnableVertexAttribArray(VertexAttribs.position.rawValue)
	glEnableVertexAttribArray(VertexAttribs.normal.rawValue)
	
	glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
	
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	// Point out vertex positions
	glVertexAttribPointer(VertexAttribs.position.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<ScaleVertex>.stride), BUFFER_OFFSET(0))
	glVertexAttribPointer(VertexAttribs.normal.rawValue, 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												GLsizei(MemoryLayout<ScaleVertex>.stride), BUFFER_OFFSET(UInt32(MemoryLayout<Float>.stride * 2)))
	
	var cursor: GLsizei = 0
	for range in primitive.elementCounts {
		glDrawArrays(GLenum(GL_TRIANGLE_STRIP),
								 cursor,
								 range)
		cursor += range
	}
	glDisableVertexAttribArray(VertexAttribs.normal.rawValue)
}

