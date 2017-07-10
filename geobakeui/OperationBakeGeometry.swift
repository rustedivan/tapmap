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
		
		if let encoded = world.encoded {
			let didWrite = NSKeyedArchiver.archiveRootObject(encoded, toFile: tempUrl.path)
			guard didWrite else { print("Save failed"); return }
		} else {
			print("Encoding failed")
		}
		
		let loadedWorldCoding = NSKeyedUnarchiver.unarchiveObject(withFile: tempUrl.path) as? GeoWorld.Coding
		let loadedWorld = loadedWorldCoding?.decoded as? GeoWorld
		print("\(String(describing: loadedWorld))")
	}
}
