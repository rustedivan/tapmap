//
//  GameViewController.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-03-31.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import GLKit
import OpenGLES
import SwiftyJSON

func BUFFER_OFFSET(_ i: UInt32) -> UnsafeRawPointer? {
	return UnsafeRawPointer(bitPattern: Int(i))
}

let UNIFORM_MODELVIEWPROJECTION_MATRIX = 0
var uniforms = [GLint](repeating: 0, count: 2)

class GameViewController: GLKViewController {
	var geoWorld: GeoWorld!
	var continentRenderers : [GeoContinentRenderer] = []
	
	var program: GLuint = 0
	
	var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
	
	var context: EAGLContext? = nil
	
	deinit {
		self.tearDownGL()
		
		if EAGLContext.current() === self.context {
			EAGLContext.setCurrent(nil)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		geoWorld = loadFeatureJson()

		self.context = EAGLContext(api: .openGLES2)
		
		if !(self.context != nil) {
			print("Failed to create ES context")
		}
		
		let view = self.view as! GLKView
		view.context = self.context!
		view.drawableDepthFormat = .format24
		
		self.setupGL()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		
		if self.isViewLoaded && (self.view.window != nil) {
			self.view = nil
			
			self.tearDownGL()
			
			if EAGLContext.current() === self.context {
				EAGLContext.setCurrent(nil)
			}
			self.context = nil
		}
	}
	
	func setupGL() {
		EAGLContext.setCurrent(self.context)
		
		if(self.loadShaders() == false) {
			print("Failed to load shaders")
		}
		
		glEnable(GLenum(GL_DEPTH_TEST))
		for continent in geoWorld.continents {
			continentRenderers.append(GeoContinentRenderer(continent: continent))
		}
	}
	
	func tearDownGL() {
		EAGLContext.setCurrent(self.context)
		
		if program != 0 {
			glDeleteProgram(program)
			program = 0
		}
	}
	
	// MARK: - GLKView and GLKViewController delegate methods
	
	func update() {
		let projectionMatrix = GLKMatrix4MakeOrtho(-180.0, 180.0, -80.0, 80.0, 0.1, 2.0)
		let zoom = 5.0 + 4.0 * sin(timeSinceLastResume * 0.5)
		let lat = 90.0 * cos(timeSinceLastResume * 0.37)
		let lng = 25.0 * sin(timeSinceLastResume * 0.23)

		// Compute the model view matrix for the object rendered with GLKit
		var modelViewMatrix = GLKMatrix4MakeScale(Float(zoom), Float(zoom), 1.0)
		modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, Float(lat), Float(lng), -1.5)
		modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.0, 0.0, 0.0, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		// Render the object again with ES2
		glUseProgram(program)
		
		withUnsafePointer(to: &modelViewProjectionMatrix, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, $0)
			})
		})
	
		var i = 0
		for continent in geoWorld.continents {
			for region in continent.regions {
				for feature in region.parts {
					continentRenderers[i].renderFeature(feature)
				}
			}
			i += 1
		}
	}
	
	// MARK: -  OpenGL ES 2 shader compilation
	
	func loadShaders() -> Bool {
		var vertShader: GLuint = 0
		var fragShader: GLuint = 0
		var vertShaderPathname: String
		var fragShaderPathname: String
		
		// Create shader program.
		program = glCreateProgram()
		
		// Create and compile vertex shader.
		vertShaderPathname = Bundle.main.path(forResource: "Shader", ofType: "vsh")!
		if self.compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
			print("Failed to compile vertex shader")
			return false
		}
		
		// Create and compile fragment shader.
		fragShaderPathname = Bundle.main.path(forResource: "Shader", ofType: "fsh")!
		if !self.compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
			print("Failed to compile fragment shader")
			return false
		}
		
		// Attach vertex shader to program.
		glAttachShader(program, vertShader)
		
		// Attach fragment shader to program.
		glAttachShader(program, fragShader)
		
		// Bind attribute locations.
		// This needs to be done prior to linking.
		glBindAttribLocation(program, GLuint(GLKVertexAttrib.position.rawValue), "position")
		
		// Link program.
		if !self.linkProgram(program) {
			print("Failed to link program: \(program)")
			
			if vertShader != 0 {
				glDeleteShader(vertShader)
				vertShader = 0
			}
			if fragShader != 0 {
				glDeleteShader(fragShader)
				fragShader = 0
			}
			if program != 0 {
				glDeleteProgram(program)
				program = 0
			}
			
			return false
		}
		
		// Get uniform locations.
		uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(program, "modelViewProjectionMatrix")
		
		// Release vertex and fragment shaders.
		if vertShader != 0 {
			glDetachShader(program, vertShader)
			glDeleteShader(vertShader)
		}
		if fragShader != 0 {
			glDetachShader(program, fragShader)
			glDeleteShader(fragShader)
		}
		
		return true
	}
	
	
	func compileShader(_ shader: inout GLuint, type: GLenum, file: String) -> Bool {
		var status: GLint = 0
		var source: UnsafePointer<Int8>
		do {
			source = try NSString(contentsOfFile: file, encoding: String.Encoding.utf8.rawValue).utf8String!
		} catch {
			print("Failed to load vertex shader")
			return false
		}
		var castSource: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(source)
		
		shader = glCreateShader(type)
		glShaderSource(shader, 1, &castSource, nil)
		glCompileShader(shader)
		
		glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
		if status == 0 {
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
			print("Program validate log: \n\(log)")
		}
		
		glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
		var returnVal = true
		if status == 0 {
			returnVal = false
		}
		return returnVal
	}
}

