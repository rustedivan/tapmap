//
//  GeoRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import UIKit.UIColor
import OpenGLES

func BUFFER_OFFSET(_ i: UInt32) -> UnsafeRawPointer? {
	return UnsafeRawPointer(bitPattern: Int(i))
}

typealias Color = (r: Float, g: Float, b: Float, a: Float)
extension UIColor {
	func tuple() -> Color {
		var out: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.0, 0.0, 0.0)
		getRed(&out.r, green: &out.g, blue: &out.b, alpha: nil)
		return Color(r: Float(out.r), g: Float(out.g), b: Float(out.b), a: 1.0)
	}
}

enum VertexAttribs: GLuint {
	case position = 1
	case miter = 2
	case scalar = 3
}

extension GeoRegion : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> PrimitiveType {
		let c = hashColor(ofHash: parentHash, childHash: hashValue).tuple()
		return ArrayedRenderPrimitive(vertices: geometry.vertices, color: c, ownerHash: hashValue, debugName: "Region: \(name)")
	}
	
	func placesRenderPlane() -> IndexedRenderPrimitive {
		let (vertices, indices, scalars) = buildPlaceMarkers(places: places, markerSize: 0.3)
		
		return IndexedRenderPrimitive(vertices: vertices,
																	indices: indices, scalarAttribs: scalars,
													 color: (r: 0.7, g: 0.7, b: 0.7, a: 1.0),
													 ownerHash: hashValue,
													 debugName: "Region: \(name) - poi plane")
	}
}

extension GeoCountry : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> PrimitiveType {
		let c = hashColor.tuple()
		return ArrayedRenderPrimitive(vertices: geometry.vertices, color: c, ownerHash: hashValue, debugName: "Country: \(name)")
	}
	
	func placesRenderPlane() -> IndexedRenderPrimitive {
		let (vertices, indices, scalars) = buildPlaceMarkers(places: places, markerSize: 0.4)
		
		return IndexedRenderPrimitive(vertices: vertices,
													 indices: indices, scalarAttribs: scalars,
													 color: (r: 0.8, g: 0.3, b: 0.0, a: 1.0),
													 ownerHash: hashValue,
													 debugName: "Country: \(name) - poi plane")
	}
}

extension GeoContinent : Renderable {
	typealias PrimitiveType = ArrayedRenderPrimitive
	func renderPrimitive() -> PrimitiveType {
		let c = hashColor.tuple()
		return ArrayedRenderPrimitive(vertices: geometry.vertices, color: c, ownerHash: hashValue, debugName: "Continent \(name)")
	}
	
	func placesRenderPlane() -> IndexedRenderPrimitive {
		let (vertices, indices, scalars) = buildPlaceMarkers(places: places, markerSize: 1.0)
		return IndexedRenderPrimitive(vertices: vertices,
																	indices: indices, scalarAttribs: scalars,
																	color: (r: 1.0, g: 0.5, b: 0.5, a: 1.0),
																	ownerHash: hashValue,
																	debugName: "Continent: \(name) - poi plane")
	}
}

func loadShaders(shaderName: String) -> GLuint {
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
	glBindAttribLocation(program, VertexAttribs.position.rawValue, "position")
	glBindAttribLocation(program, VertexAttribs.miter.rawValue, "miter")
	glBindAttribLocation(program, VertexAttribs.scalar.rawValue, "scalar")
	
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


func compileShader(_ shader: inout GLuint, type: GLenum, file: String) -> Bool {
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

func linkProgram(_ prog: GLuint) -> Bool {
	var status: GLint = 0
	glLinkProgram(prog)
	
	glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
	if status == 0 {
		return false
	}
	
	return true
}

func validateProgram(prog: GLuint) -> Bool {
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
