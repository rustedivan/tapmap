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
	@IBOutlet var regionOutline : RegionOutlineView!
	let loadQueue = OperationQueue()
	let saveQueue = OperationQueue()
	var loadJob : Operation?
	var saveJob : Operation?
	var workWorld: GeoWorld?
	
	override func viewDidAppear() {
		loadQueue.name = "Json load queue"
		loadQueue.qualityOfService = .userInitiated
		saveQueue.name = "Geometry save queue"
		saveQueue.qualityOfService = .userInitiated
		regionOutline.isHidden = true
		// Autoload or open file picker
		if let autoUrl = tryAutoloadWithArgument(arguments: CommandLine.arguments) {
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
	
	@IBAction func bakeGeometry(sender: NSButton) {
		let window = self.view.window!
		let panel = NSSavePanel()
		panel.message = "Save pre-baked tapmap geometry"
		panel.allowedFileTypes = ["geo"]
		panel.beginSheetModal(for: window) { (result) in
			if result == NSFileHandlingPanelOKButton {
				if let url = panel.url {
					self.asyncBakeGeometry(to: url)
				}
			}
		}
	}
	
	func tryAutoloadWithArgument(arguments: [String]) -> URL? {
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

extension ViewController : GeoLoadingViewDelegate {
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
			DispatchQueue.main.async {
				if let world = jsonParser.resultWorld {
					self.finishLoad(loadedWorld: world)
				} else {
					print("Load failed")
					self.cancelLoad()
				}
			}
		}
		
		loadJob = jsonParser
		loadQueue.addOperation(jsonParser)
	}

	func finishLoad(loadedWorld: GeoWorld) {
		workWorld = loadedWorld
		regionOutline.world = loadedWorld
		regionOutline.isHidden = false
		regionOutline.reloadData()
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

extension ViewController : GeoBakingViewDelegate {
	func startBaking() -> (ProgressReport, ErrorReport) {
		performSegue(withIdentifier: "ShowBakingProgress", sender: self)
		let baking = presentedViewControllers?.last as! GeoBakingViewController
		baking.delegate = self
		return (baking.progressReporter, baking.errorReporter)
	}
	
	func asyncBakeGeometry(to url: URL) {
		let (reporter, errorReporter) = startBaking()

		let geometryBaker = OperationBakeGeometry(workWorld!, reporter: reporter, errorReporter: errorReporter)
		geometryBaker.completionBlock = {
			guard !geometryBaker.isCancelled else { return }
			guard geometryBaker.error == nil else {
				print(String(describing: geometryBaker.error))
				return
			}
			reporter(1.0, "Done", true)	// Close the baking panel
			self.finishSave(tempUrl: geometryBaker.tempUrl, saveUrl: url)
		}
		
		saveJob = geometryBaker
		saveQueue.addOperation(geometryBaker)
	}
	
	func finishSave(tempUrl fromUrl: URL, saveUrl toUrl: URL) {
		do {
			try FileManager.default.moveItem(at: fromUrl, to: toUrl)
		} catch (let e) {
			print(e)
		}
	}
	
	func cancelSave() {
		if let baking = presentedViewControllers?.last as? GeoBakingViewController {
			dismissViewController(baking)
		}
		if let saveJob = saveJob {
			saveJob.cancel()
		}
	}
}
