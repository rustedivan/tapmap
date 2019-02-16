//
//  OperationBakeGeometry.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation

class OperationBakeGeometry : Operation {
	let input : Set<ToolGeoFeature>
	let saveUrl : URL
	let report : ProgressReport
	let reportError : ErrorReport
	
	init(world worldToBake: Set<ToolGeoFeature>,
			 saveUrl url: URL,
	     reporter: @escaping ProgressReport,
	     errorReporter: @escaping ErrorReport) {
		input = worldToBake
		saveUrl = url
		report = reporter
		reportError = errorReporter
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		// Bake job should only do this conversion and save
		let bakedWorld = buildWorld(from: input)
		
		print("\n")
		report(0.1, "Writing world to \(saveUrl.lastPathComponent)...", false)
		
		let encoder = PropertyListEncoder()
		
		if let encoded = try? encoder.encode(bakedWorld) {
			do {
				try encoded.write(to: saveUrl, options: .atomicWrite)
				print("GeoWorld baked to \(ByteCountFormatter().string(fromByteCount: Int64(encoded.count)))")
			} catch {
				print("Saving failed")
			}
		}
		else {
			print("Encoding failed")
		}
		report(1.0, "Done.", true)
	}
	
	func buildWorld(from: Set<ToolGeoFeature>) -> GeoWorld {
		var worldResult = Set<GeoContinent>()
		
		// Build continents
		for continent in input {
			guard let continentTessellation = continent.tessellation else {
				print("\(continent.name) has no tessellation - skipping...")
				continue
			}
			
			// Build countries
			var countryResult = Set<GeoCountry>()
			for country in continent.children ?? [] {
				
				// Build regions
				var regionResult = Set<GeoRegion>()
				for region in country.children ?? [] {
					guard let regionTessellation = region.tessellation else {
						print("\(region.name) has no tessellation - skipping...")
						continue
					}
					
					let geoRegion = GeoRegion(name: region.name,
																		geometry: regionTessellation,
																		places: region.places ?? [])
					regionResult.insert(geoRegion)
				}
				
				guard let countryTessellation = country.tessellation else {
					print("\(country.name) has no tessellation - skipping...")
					continue
				}
				
				let geoCountry = GeoCountry(name: country.name,
																		children: regionResult,
																		places: country.places ?? [],
																		geometry: countryTessellation)
				countryResult.insert(geoCountry)
			}
			
			let geoContinent = GeoContinent(name: continent.name,
																			children: countryResult,
																			places: continent.places ?? [],
																			geometry: continentTessellation)
			worldResult.insert(geoContinent)
		}
		return GeoWorld(name: "Earth", children: worldResult)
	}
}
