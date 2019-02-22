//
//  GeoRenderer.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import OpenGLES
import GLKit

func BUFFER_OFFSET(_ i: UInt32) -> UnsafeRawPointer? {
	return UnsafeRawPointer(bitPattern: Int(i))
}

typealias Color = (r: Float, g: Float, b: Float, a: Float)
func hashColor<T:Hashable>(for h: T, _ rw: Float, _ gw: Float, _ bw: Float, a: Float = 1.0) -> Color {
	let hash = abs(h.hashValue)
	let r = Float(hash % 1000) / 1000.0
	let g = Float(hash % 1000) / 1000.0
	let b = Float(hash % 1000) / 1000.0
	
	return (r: r * rw, g: g * gw, b: b * bw, a: a)
}

class RenderPrimitive {
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	let indexCount: GLsizei
	let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
	let name: String
	
	init(vertices: [Vertex], indices: [UInt32], color c: (r: Float, g: Float, b: Float, a: Float), debugName: String) {
		color = c
		
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		
		glBufferData(GLenum(GL_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<Vertex>.size * vertices.count),
								 vertices,
		             GLenum(GL_STATIC_DRAW))
		
		indexCount = GLsizei(indices.count)
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
		             GLsizeiptr(MemoryLayout<GLint>.size * indices.count),
								 indices,
		             GLenum(GL_STATIC_DRAW))
		
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), vertexBuffer, 0, "\(debugName).vertices")
		glLabelObjectEXT(GLenum(GL_BUFFER_OBJECT_EXT), indexBuffer, 0, "\(debugName).indices")
		name = debugName
	}
	
	deinit {
		glDeleteBuffers(1, &indexBuffer)
		glDeleteBuffers(1, &vertexBuffer)
	}
}

func render(primitive: RenderPrimitive) {
	glEnableClientState(GLenum(GL_VERTEX_ARRAY))
	glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
	
	glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), primitive.indexBuffer)
	glBindBuffer(GLenum(GL_ARRAY_BUFFER), primitive.vertexBuffer)
	
	glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2,
												GLenum(GL_FLOAT), GLboolean(GL_FALSE),
												8, BUFFER_OFFSET(0))
	
	glDrawElements(GLenum(GL_TRIANGLES),
								 primitive.indexCount,
								 GLenum(GL_UNSIGNED_INT),
								 BUFFER_OFFSET(0))
}

func buildPlaceMarkers(places: Set<GeoPlace>, markerSize: Float) -> ([Vertex], [UInt32]) {
	let vertices = places.reduce([]) { (accumulator: [Vertex], place: GeoPlace) in
		let size = markerSize / 2.0
		let v0 = Vertex(0.0, size)
		let v1 = Vertex(size, 0.0)
		let v2 = Vertex(0.0, -size)
		let v3 = Vertex(-size, 0.0)
		let verts = [v0, v1, v2, v3].map { $0 + place.location }
		return accumulator + verts
	}

	let triangleRange = 0..<UInt32(places.count * 2)
	let indices = triangleRange.reduce([]) { (accumulator: [UInt32], triIndex: UInt32) in
		let quadIndices: [UInt32] = [0, 2, 1, 0, 3, 2]	// Build two triangles from the four quad vertices
		let vertexOffset = triIndex * 4
		let offsetIndices = quadIndices.map { $0 + vertexOffset }
		return accumulator + offsetIndices
	}
	
	return (vertices, indices)
}

extension GeoRegion : Renderable {
	func renderPrimitive() -> RenderPrimitive {
		let c = hashColor(for: name, 0.5, 0.8, 0.3)
		return RenderPrimitive(vertices: geometry.vertices, indices: geometry.indices, color: c, debugName: "Region: \(name)")
	}
	
	func placesRenderPlane() -> RenderPrimitive {
		let (vertices, indices) = buildPlaceMarkers(places: places, markerSize: 0.3)
		
		return RenderPrimitive(vertices: vertices,
													 indices: indices,
													 color: (r: 0.7, g: 0.7, b: 0.7, a: 1.0),
													 debugName: "Region: \(name) - poi plane")
	}
}

extension GeoCountry : Renderable {
	func renderPrimitive() -> RenderPrimitive {
		let c = hashColor(for: name, 0.4, 0.6, 0.4)
		return RenderPrimitive(vertices: geometry.vertices, indices: geometry.indices, color: c, debugName: "Country: \(name)")
	}
	
	func placesRenderPlane() -> RenderPrimitive {
		let (vertices, indices) = buildPlaceMarkers(places: places, markerSize: 0.4)
		
		return RenderPrimitive(vertices: vertices,
													 indices: indices,
													 color: (r: 0.8, g: 0.3, b: 0.0, a: 1.0),
													 debugName: "Country: \(name) - poi plane")
	}
}

extension GeoContinent : Renderable {
	func renderPrimitive() -> RenderPrimitive {
		let c = hashColor(for: name, 0.4, 0.5, 0.1)
		return RenderPrimitive(vertices: geometry.vertices, indices: geometry.indices, color: c, debugName: "Continent \(name)")
	}
	
	func placesRenderPlane() -> RenderPrimitive {
		let (vertices, indices) = buildPlaceMarkers(places: places, markerSize: 1.0)
		return RenderPrimitive(vertices: vertices,
													 indices: indices,
													 color: (r: 1.0, g: 0.5, b: 0.5, a: 1.0),
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
