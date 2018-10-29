//
//  ViewController.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-04-08.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa
import SwiftyJSON
import Dispatch

typealias ProgressReport = (Double, String, Bool) -> ()
typealias ErrorReport = (String, String) -> ()

class ViewController: NSViewController {
	@IBOutlet var regionOutline : RegionOutlineView!
	let loadQueue = OperationQueue()
	let saveQueue = OperationQueue()
	var loadJob : Operation?
	var saveJob : Operation?
	var workWorld: GeoFeatureCollection?
	
	override func viewDidAppear() {
		loadQueue.name = "Json load queue"
		loadQueue.qualityOfService = .userInitiated
		saveQueue.name = "Geometry save queue"
		saveQueue.qualityOfService = .userInitiated
		
		regionOutline.isHidden = true
		
		autoloadOrOpen()
	}
	
	@IBAction func bakeGeometry(sender: NSButton) {
		let window = self.view.window!
		let panel = NSSavePanel()
		panel.message = "Save pre-baked tapmap geometry"
		panel.allowedFileTypes = ["geo"]
		panel.beginSheetModal(for: window) { (result) in
			if result.rawValue == NSFileHandlingPanelOKButton {
				if let url = panel.url {
					self.asyncBakeGeometry(to: url)
				}
			}
		}
	}
	
	func autoloadOrOpen() {
		// Autoload or open file picker
		if let autoUrl = tryAutoloadWithArgument(arguments: CommandLine.arguments) {
			asyncLoadJson(countriesFrom: autoUrl.0, regionsFrom: autoUrl.1)
		} else {
			let window = self.view.window!
			
			let panel = NSOpenPanel()
			var countryUrl: URL?
			var regionUrl: URL?
			panel.message = "Please choose a country-feature json file."
			panel.allowedFileTypes = ["json"]
			
			panel.beginSheetModal(for: window) { result in
				if result.rawValue == NSFileHandlingPanelOKButton {
					countryUrl = panel.urls.first
				}
			}
			
			panel.message = "Please choose a region-feature json file."
			panel.beginSheetModal(for: window) { result in
				if result.rawValue == NSFileHandlingPanelOKButton {
					regionUrl = panel.urls.first
				}
			}
			
			guard let cUrl = countryUrl, let rUrl = regionUrl else {
				print("Error")
				return
			}
			
			asyncLoadJson(countriesFrom: cUrl, regionsFrom: rUrl)
		}
	}
	
	func tryAutoloadWithArgument(arguments: [String]) -> (URL, URL)? {
		var jsons : [URL] = []
		
		jsons = arguments.compactMap( {
			$0.hasSuffix(".json")
				? Bundle.main.bundleURL
						.deletingLastPathComponent()
						.appendingPathComponent("SourceData")
						.appendingPathComponent($0)
				: nil
		})
		
		guard jsons.count == 2 else {
			print("Invalid arguments. Pass <countries> <regions>.")
			return nil
		}
		
		return (jsons[0], jsons[1])
	}
}
