//
//  OperationTintRegions.swift
//  geobaketool
//
//  Created by Ivan Milles on 2020-10-31.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation
import AppKit.NSImage

class OperationTintRegions : Operation {
	let input : ToolGeoFeatureMap
	
	var output : ToolGeoFeatureMap
	let report : ProgressReport
	let colorMap : NSBitmapImageRep
	
	init(features: ToolGeoFeatureMap,
			 colorMap image: NSBitmapImageRep,
			 reporter: @escaping ProgressReport) {
		
		input = features
		report = reporter
		colorMap = image
		
		output = [:]
		
		super.init()
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		for (key, feature) in input {
			let h = Float((feature.tessellations[0].visualCenter.x + 180.0) / 360.0)
			let l = Float((feature.tessellations[0].visualCenter.y + 90.0) / 180.0)
			let u = Int(h * Float(colorMap.pixelsWide))
			let v = Int((1.0 - l) * Float(colorMap.pixelsHigh))
			
			// Pick geoColor
			let pickedColor = colorMap.colorAt(x: u, y: v)!
			var components: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.0, 0.0, 0.0)
			pickedColor.getRed(&components.r, green: &components.g, blue: &components.b, alpha: nil)
			let tessColor = GeoColor(r: Float(components.r), g: Float(components.g), b: Float(components.b))
			
			let tintedTessellations = feature.tessellations.map {
				return GeoTessellation(vertices: $0.vertices,
															 indices: $0.indices,
															 contours: $0.contours,
															 aabb: $0.aabb,
															 visualCenter: $0.visualCenter,
															 color: tessColor)
			}
			
			let updatedFeature = ToolGeoFeature(level: feature.level,
																				polygons: feature.polygons,
																				tessellations: tintedTessellations,
																				places: feature.places,
																				children: feature.children,
																				stringProperties: feature.stringProperties,
																				valueProperties: feature.valueProperties)
			output[key] = updatedFeature
			if (output.count > 0) {
				let reportLine = "\(feature.name) colored"
				report((Double(output.count) / Double(input.count)), reportLine, false)
			}
		}
	}
	
	static func storeNewColorMap() {
		guard let inputPath = PipelineConfig.shared.inputColorMapPath,
					let outputPath = PipelineConfig.shared.storedColorMapPath else { return }
		do {
			try FileManager.default.replaceItem(at: outputPath, withItemAt: inputPath, backupItemName: nil, resultingItemURL: nil)
		} catch {
			print("Could not copy new color map to pipeline storage")
		}
	}
	
	static func loadColorMap() -> NSImage {
		guard let colorMapPath = PipelineConfig.shared.storedColorMapPath else { fatalError("No color map found in pipeline storage.") }
		
		let colorMap = NSImage(byReferencing: colorMapPath)
		if colorMap.isValid {
			print("Loaded color map...")
		} else {
			fatalError("Could not load color map from \(colorMapPath.absoluteString)")
		}
		return colorMap
	}
}


