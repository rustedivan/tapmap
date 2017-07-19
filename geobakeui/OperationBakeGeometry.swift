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
		
		let encoder = PropertyListEncoder()
		
		if let encoded = try? encoder.encode(tessellatedWorld) {
			do {
				// FIXME: not needed, atomic write handles this temp stuff
				try encoded.write(to: tempUrl, options: .atomicWrite)
			} catch {
				print("Saving failed")
			}
		}
		else {
			print("Encoding failed")
		}
	}
}
