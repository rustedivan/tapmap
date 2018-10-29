//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let countries : GeoFeatureCollection
	let regions : GeoFeatureCollection
	let saveUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	var error : Error?
	
	init(countries countriesToBake: GeoFeatureCollection,
			 region regionsToBake: GeoFeatureCollection,
			 saveUrl url: URL,
	     reporter: @escaping ProgressReport,
	     errorReporter: @escaping ErrorReport) {
		countries = countriesToBake
		regions = regionsToBake
		saveUrl = url
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		let tessQueue = OperationQueue()
		tessQueue.name = "Tessellation queue"
		let tessJob1 = OperationTessellateRegions(countries, reporter: report, errorReporter: reportError)
		let tessJob2 = OperationTessellateRegions(regions, reporter: report, errorReporter: reportError)
		
		// $ Run two tessjobs
		// $ When they finish, run the fixup
		// $ Build a full-hierarchy GeoWorld
		// $ Save
		
		tessJob1.start()
		tessJob2.start()
		
		tessQueue.waitUntilAllOperationsAreFinished()
		
		print("Building a world with \(tessJob1.tessellatedRegions.count) country regions and \(tessJob2.tessellatedRegions.count) province regions.")
		
		let tessellatedWorld = GeoWorld(regions: tessJob1.tessellatedRegions)
		report(1.0, "Finished tesselation.", true)
		print("Persisting...")
		
		let encoder = PropertyListEncoder()
		
		if let encoded = try? encoder.encode(tessellatedWorld) {
			do {
				try encoded.write(to: saveUrl, options: .atomicWrite)
			} catch {
				print("Saving failed")
			}
		}
		else {
			print("Encoding failed")
		}
	}
}
