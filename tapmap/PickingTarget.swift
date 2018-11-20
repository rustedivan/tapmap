//
//  PickingRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-11-06.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import OpenGLES
import CoreGraphics.CGGeometry
import GLKit

class PickingTarget {
	var frameBuffer: GLuint
	var renderBuffer: GLuint
	let pickBoxDimension = 64
	var pickBoxSize: CGSize { get { return CGSize(width: pickBoxDimension, height: pickBoxDimension) } }
	
	init() {
		var f: GLuint = 0
		glGenFramebuffers(1, &f);
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), f, 0, "Picking framebuffer")
		frameBuffer = f
		glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer);
		
		var r: GLuint = 0
		glGenRenderbuffers(1, &r)
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), r, 0, "Picking renderbuffer")
		renderBuffer = r
		glBindRenderbuffer(GLenum(GL_RENDERBUFFER), r)
		
		glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_R16F), GLsizei(pickBoxDimension), GLsizei(pickBoxDimension))
		glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), r)
		
		let bufferStatus = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
		guard bufferStatus == GLenum(GL_FRAMEBUFFER_COMPLETE) else {
			print("Picking buffer is incomplete: \(bufferStatus)")
			glDeleteFramebuffers(1, &frameBuffer)
			glDeleteRenderbuffers(1, &renderBuffer)
			return
		}

		glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
	}
	
	deinit {
		glDeleteFramebuffers(1, &frameBuffer)
		glDeleteRenderbuffers(1, &renderBuffer)
	}
	
	func renderPickingMap(world: GeoWorld, renderer: MapRenderer, projection: GLKMatrix4) {
		glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer);
			glClearColor(0.0, 0.0, 0.0, 1.0)
			glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
			glViewport(0, 0, GLsizei(pickBoxDimension), GLsizei(pickBoxDimension))
			renderer.renderPickPlane(geoWorld: world, inProjection: projection)
		
			let bufferSize = pickBoxDimension * pickBoxDimension * MemoryLayout<Float>.stride
			if let buffer: UnsafeMutableRawPointer = malloc(bufferSize)
			{
				glReadPixels(0, 0, GLsizei(pickBoxDimension), GLsizei(pickBoxDimension), GLenum(GL_R16F), GLenum(GL_FLOAT), buffer)
				let _ = buffer.assumingMemoryBound(to: Float.self)
				
				free(buffer)
		}
		
		glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0);
	}
}

func pickFromRegions(p: CGPoint, regions: Set<GeoRegion>) -> GeoRegion? {
	for region in regions {
		if triangleSoupHitTest(point: p, inVertices: region.geometry.vertices, inIndices: region.geometry.indices) {
			return region
		}
	}
	return nil
}
