//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let world : GeoWorld
	let saveUrl : URL
	let tempUrl : URL
	let report : ProgressReport
	var error : Error?
	
	init(_ worldToBake: GeoWorld, toUrl url: URL, reporter: @escaping ProgressReport) {
		world = worldToBake
		tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
		saveUrl = url
		report = reporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		let didWrite = NSKeyedArchiver.archiveRootObject(world, toFile: tempUrl.path)
		guard didWrite else { print("Save failed"); return }
		
		do {
			try FileManager.default.moveItem(at: tempUrl, to: saveUrl)
		} catch (let e) {
			error = e
			return
		}
	}
}

class GeoWorldFileWrapper : NSCoding {
	let wrappedWorld: GeoWorld
	init(world: GeoWorld) {
		wrappedWorld = world
	}
	
	required init?(coder aDecoder: NSCoder) {
		wrappedWorld = GeoWorld(continents: [])
	}
	
	func encode(with aCoder: NSCoder) {
		
	}
}
