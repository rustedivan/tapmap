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
	let tempUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(_ worldToBake: GeoWorld,
	     reporter: @escaping ProgressReport,
	     errorReporter: @escaping ErrorReport) {
		world = worldToBake
		tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("tapmap-geobake.geometry")
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		let tessQueue = OperationQueue()
		tessQueue.name = "Tessellation queue"
		let tessJob = OperationTessellateBorders(world, reporter: report, errorReporter: reportError)
		
		tessJob.start()
		report(1.0, "Finished tesselation.", true)
		
		let worldWrapper = GeoWorldFileWrapper(world: world)
		let didWrite = NSKeyedArchiver.archiveRootObject(worldWrapper, toFile: tempUrl.path)
		guard didWrite else { print("Save failed"); return }
	}
}

class GeoWorldFileWrapper : NSObject, NSCoding {
	let wrappedWorld: GeoWorld
	init(world: GeoWorld) {
		wrappedWorld = world
	}
	
	required init?(coder aDecoder: NSCoder) {
		wrappedWorld = GeoWorld(continents: [])
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(wrappedWorld)
	}
}
