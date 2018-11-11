//
//  MapRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2018-01-27.
//  Copyright © 2018 Wildbrain. All rights reserved.
//

import OpenGLES
import GLKit


func BUFFER_OFFSET(_ i: UInt32) -> UnsafeRawPointer? {
	return UnsafeRawPointer(bitPattern: Int(i))
}

class MapRenderer {
	let regionPrimitives : [RenderPrimitive]
	let mapProgram: GLuint
	let mapUniforms : (modelViewMatrix: GLint, color: GLint)
	
	
	init?(withGeoWorld geoWorld: GeoWorld) {
		
		mapProgram = loadShaders(shaderName: "MapShader")
		guard mapProgram != 0 else {
			print("Failed to load map shaders")
			return nil
		}
		mapUniforms.modelViewMatrix = glGetUniformLocation(mapProgram, "modelViewProjectionMatrix")
		mapUniforms.color = glGetUniformLocation(mapProgram, "regionColor")
		
		
		regionPrimitives = geoWorld.countries.flatMap { country -> [RenderPrimitive] in
			if country.opened {
				return country.regions.flatMap { [$0.renderPrimitive()] }
			} else {
				return [country.geography.renderPrimitive()]
			}
		}
	}
	
	deinit {
		if mapProgram != 0 {
			glDeleteProgram(mapProgram)
		}
	}
	
	func renderWorld(geoWorld: GeoWorld, inProjection projection: GLKMatrix4) {
		glPushGroupMarkerEXT(0, "Render world")
		glUseProgram(mapProgram)
		
		var mutableProjection = projection // The 'let' argument is not safe to pass into withUnsafePointer. No copy, since copy-on-write.
		withUnsafePointer(to: &mutableProjection, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(mapUniforms.modelViewMatrix, 1, 0, $0)
			})
		})
		
		for primitive in regionPrimitives {
			var components : [GLfloat] = [primitive.color.r, primitive.color.g, primitive.color.b, 1.0]
			glUniform4f(mapUniforms.color,
									GLfloat(components[0]),
									GLfloat(components[1]),
									GLfloat(components[2]),
									GLfloat(components[3]))
			render(primitive: primitive)
		}
		glPopGroupMarkerEXT()
	}
	
	}
}

fileprivate func loadShaders(shaderName: String) -> GLuint {
	var program: GLuint = 0
	var vertShader: GLuint = 0
	var fragShader: GLuint = 0
	var vertShaderPathname: String
	var fragShaderPathname: String
	
	// Create shader program.
	program = glCreateProgram()
	
	// Create and compile vertex shader.
	vertShaderPathname = Bundle.main.path(forResource: shaderName, ofType: "vsh")!
	if compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
		return 0
	}
	
	// Create and compile fragment shader.
	fragShaderPathname = Bundle.main.path(forResource: shaderName, ofType: "fsh")!
	if !compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
		return 0
	}
	
	// Attach vertex shader to program.
	glAttachShader(program, vertShader)
	
	// Attach fragment shader to program.
	glAttachShader(program, fragShader)
	
	// Bind attribute locations.
	// This needs to be done prior to linking.
	glBindAttribLocation(program, GLuint(GLKVertexAttrib.position.rawValue), "position")
	
	// Link program.
	if !linkProgram(program) {
		print("Failed to link program: \(program)")
		
		if vertShader != 0 {
			glDeleteShader(vertShader)
		}
		if fragShader != 0 {
			glDeleteShader(fragShader)
		}
		if program != 0 {
			glDeleteProgram(program)
		}
		
		return 0
	}
	
	// Release vertex and fragment shaders.
	if vertShader != 0 {
		glDetachShader(program, vertShader)
		glDeleteShader(vertShader)
	}
	if fragShader != 0 {
		glDetachShader(program, fragShader)
		glDeleteShader(fragShader)
	}
	
	return program
}


fileprivate func compileShader(_ shader: inout GLuint, type: GLenum, file: String) -> Bool {
	var status: GLint = 0
	do {
		var source: UnsafePointer<Int8>
		var castSource: UnsafePointer<GLchar>?
		
		source = try NSString(contentsOfFile: file, encoding: String.Encoding.utf8.rawValue).utf8String!
		castSource = UnsafePointer<GLchar>(source)
		shader = glCreateShader(type)
		glShaderSource(shader, 1, &castSource, nil)
		glCompileShader(shader)
	} catch {
		print("Failed to load vertex shader")
		return false
	}
	
	glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
	if status == 0 {
		var log: [GLchar] = [GLchar](repeating: 0, count: Int(1024))
		glGetShaderInfoLog(shader, 1024, nil, &log)
		print("Failed to compile shader: \(String(cString: log))")
		glDeleteShader(shader)
		return false
	}
	
	return true
}

fileprivate func linkProgram(_ prog: GLuint) -> Bool {
	var status: GLint = 0
	glLinkProgram(prog)
	
	glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
	if status == 0 {
		return false
	}
	
	return true
}

fileprivate func validateProgram(prog: GLuint) -> Bool {
	var logLength: GLsizei = 0
	var status: GLint = 0
	
	glValidateProgram(prog)
	glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
	if logLength > 0 {
		var log: [GLchar] = [GLchar](repeating: 0, count: Int(logLength))
		glGetProgramInfoLog(prog, logLength, &logLength, &log)
		print("Program validate log: \n\(String(cString: log))")
	}
	
	glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
	var returnVal = true
	if status == 0 {
		returnVal = false
	}
	return returnVal
}
