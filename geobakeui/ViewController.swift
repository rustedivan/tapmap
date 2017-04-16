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

class ViewController: NSViewController {
	let loadQueue = OperationQueue()
	var loadJob : Operation?
	
	override func viewDidAppear() {
		loadQueue.name = "Json load queue"
		
		// Autoload or open file picker
		if let autoUrl = tryAutobakeWithArgument(arguments: CommandLine.arguments) {
			asyncLoadJson(from: autoUrl)
		} else {
			let window = self.view.window!
			let panel = NSOpenPanel()
			panel.message = "Please choose a feature json file"
			panel.allowedFileTypes = ["json"]
			panel.beginSheetModal(for: window) { result in
				if result == NSFileHandlingPanelOKButton {
					if let url = panel.urls.first {
						self.asyncLoadJson(from: url)
					}
				}
			}
		}
	}
	
	func tryAutobakeWithArgument(arguments: [String]) -> URL? {
		for argument in arguments {
			if argument.hasSuffix(".json") {
				return Bundle.main.bundleURL
					.deletingLastPathComponent()
					.appendingPathComponent(argument)
			}
		}
		return nil
	}
}

extension ViewController {
	func startLoading() -> ProgressReport {
		performSegue(withIdentifier: "ShowLoadingProgress", sender: self)
		let loading = presentedViewControllers?.last as! GeoLoadingViewController
		loading.delegate = self
		return loading.progressReporter
	}
	
	func asyncLoadJson(from url: URL) {
		let jsonData: Data
		do {
			jsonData = try Data(contentsOf: url)
		} catch let e {
			presentError(e)
			return
		}
		
		var error: NSError?
		let json = JSON(data: jsonData, options: .allowFragments, error: &error)
		let reporter = startLoading()
		
		let jsonParser = OperationParseGeoJson(json, reporter: reporter)
		jsonParser.completionBlock = {
			guard !jsonParser.isCancelled else {
				return
			}
			reporter(1.0, "Done", true)	// Close the loading panel
			if let world = jsonParser.resultWorld {
				self.finishLoad(loadedWorld: world)
			} else {
				print("Load failed")
				self.cancelLoad()
			}
		}
		
		loadJob = jsonParser
		loadQueue.addOperation(jsonParser)
	}
}

extension ViewController : GeoLoadingViewDelegate {
	func finishLoad(loadedWorld: GeoWorld) {
		print("Loaded world.")
	}
	
	func cancelLoad() {
		if let loading = presentedViewControllers?.last as? GeoLoadingViewController {
			dismissViewController(loading)
		}
		if let loadJob = loadJob {
			loadJob.cancel()
		}
	}
}
