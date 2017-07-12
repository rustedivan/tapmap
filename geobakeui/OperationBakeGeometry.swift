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
		let tessellatedWorld = tessJob.world
		report(1.0, "Finished tesselation.", true)
		print("Persisting...")
		if let encoded = tessellatedWorld.encoded {
			NSKeyedArchiver.setClassName("GeoWorld.Coding", for: GeoWorld.Coding.self)
			NSKeyedArchiver.setClassName("GeoContinent.Coding", for: GeoContinent.Coding.self)
			NSKeyedArchiver.setClassName("GeoRegion.Coding", for: GeoRegion.Coding.self)
			NSKeyedArchiver.setClassName("GeoFeature.Coding", for: GeoFeature.Coding.self)
			NSKeyedArchiver.setClassName("GeoTessellation.Coding", for: GeoTessellation.Coding.self)
			NSKeyedArchiver.setClassName("Vertex.Coding", for: Vertex.Coding.self)
			
			let didWrite = NSKeyedArchiver.archiveRootObject(encoded, toFile: tempUrl.path)
			guard didWrite else { print("Save failed"); return }
		} else {
			print("Encoding failed")
		}
	}
}
