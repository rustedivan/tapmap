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
	var program: GLuint = 0
	
	var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
	
	var vertexBuffer: GLuint = 0
	var indexBuffer: GLuint = 1
	
	var context: EAGLContext? = nil
	var loaded = false
	deinit {
		self.tearDownGL()
		
		if EAGLContext.current() === self.context {
			EAGLContext.setCurrent(nil)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		loadCrazyVertices()
		
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
		
		glGenBuffers(1, &vertexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gBurkinaVertexData.count), &gBurkinaVertexData, GLenum(GL_STATIC_DRAW))
		
		glGenBuffers(1, &indexBuffer)
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLint>.size * gBurkinaIndexData.count), &gBurkinaIndexData, GLenum(GL_STATIC_DRAW))
		
		glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
		glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
	}
	
	func tearDownGL() {
		EAGLContext.setCurrent(self.context)
		
		glDeleteBuffers(1, &vertexBuffer)
		glDeleteBuffers(1, &indexBuffer)
		
		if program != 0 {
			glDeleteProgram(program)
			program = 0
		}
	}
	
	// MARK: - GLKView and GLKViewController delegate methods
	
	func update() {
		let projectionMatrix = GLKMatrix4MakeOrtho(-180.0, 180.0, -80.0, 80.0, 0.1, 2.0)
		//				let projectionMatrix = GLKMatrix4MakeOrtho(0.0, 90.0, 15.0, 60.0, 0.1, 2.0)
		
		let zoom = 5.0 + 4.0 * sin(timeSinceLastResume * 0.5)
		let lat = 90.0 * cos(timeSinceLastResume * 0.37)
		let lng = 25.0 * sin(timeSinceLastResume * 0.23)
		
		// Compute the model view matrix for the object rendered with GLKit
		var modelViewMatrix = GLKMatrix4MakeScale(Float(zoom), Float(zoom), 1.0)
		modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, Float(lat), Float(lng), -1.5)
		modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
	}
	
	override func glkView(_ view: GLKView, drawIn rect: CGRect) {
		glClearColor(0.65, 0.65, 0.65, 1.0)
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
		
		if loaded == false { return }
		
		// Render the object again with ES2
		glUseProgram(program)
		
		withUnsafePointer(to: &modelViewProjectionMatrix, {
			$0.withMemoryRebound(to: Float.self, capacity: 16, {
				glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, $0)
			})
		})
		
		glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
		glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
		for country in gCountryIndexData {
			glDrawElements(GLenum(GL_LINE_LOOP), GLsizei(country.count), GLenum(GL_UNSIGNED_INT), BUFFER_OFFSET(country.start * 4))
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
	
	func loadCrazyVertices() {
		let path = Bundle.main.path(forResource: "features", ofType: "json")
		let jsonData = NSData(contentsOfFile:path!)
		let json = JSON(data: jsonData! as Data)
		
		var i: UInt32 = 0
		for (contName, continent) in json.dictionaryValue {
			print("Loading \(contName)...")
			let regions = continent["regions"]
			for (_, region) in regions.dictionaryValue {
				let parts = region["coordinates"].arrayValue
				for p in parts {
					var range = (start: i, count: GLuint(0))
					let coords = p.arrayValue
					for c in coords {
						let x = c["lng"].floatValue
						let y = c["lat"].floatValue
						gBurkinaVertexData.append(x)
						gBurkinaVertexData.append(y)
						gBurkinaIndexData.append(i)
						range.count += 1
						i += 1
					}
					gCountryIndexData.append(range)
				}
			}
		}
		loaded = true
	}
}

var gCountryIndexData: [(start: GLuint, count: GLuint)] = []
var gBurkinaIndexData: [GLuint] = []
var gBurkinaVertexData: [GLfloat] = []
