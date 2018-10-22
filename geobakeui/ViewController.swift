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
	var workRegions: GeoFeatureCollection?
	var workCountries: GeoFeatureCollection?
	var workWorld: GeoFeatureCollection?

	
	override func viewDidAppear() {
		loadQueue.name = "Json load queue"
		loadQueue.qualityOfService = .userInitiated
		saveQueue.name = "Geometry save queue"
		saveQueue.qualityOfService = .userInitiated
		regionOutline.isHidden = true
		// Autoload or open file picker
		if let autoUrl = tryAutoloadWithArgument(arguments: CommandLine.arguments) {
			asyncLoadJson(from: autoUrl.0, dataset: .Countries)
			asyncLoadJson(from: autoUrl.1, dataset: .Regions)
		} else {
			let window = self.view.window!
			let panel = NSOpenPanel()
			panel.message = "Please choose a feature json file"
			panel.allowedFileTypes = ["json"]
			panel.beginSheetModal(for: window) { result in
				if result.rawValue == NSFileHandlingPanelOKButton {
					if let url = panel.urls.first {
						self.asyncLoadJson(from: url, dataset: .Countries)
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
			if result.rawValue == NSFileHandlingPanelOKButton {
				if let url = panel.url {
					self.asyncBakeGeometry(to: url)
				}
			}
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

extension ViewController : GeoLoadingViewDelegate {
	func startLoading() -> ProgressReport {
		performSegue(withIdentifier: "ShowLoadingProgress", sender: self)
		let loading = presentedViewControllers?.last as! GeoLoadingViewController
		loading.delegate = self
		return loading.progressReporter
	}
	
	func asyncLoadJson(from url: URL, dataset: GeoLoadingViewController.Dataset) {
		let jsonData: Data
		do {
			jsonData = try Data(contentsOf: url)
		} catch let e {
			presentError(e)
			return
		}
		
		let json: JSON
		do {
			json = try JSON(data: jsonData, options: .allowFragments)
		} catch let error {
				presentError(error)
				return
		}
		let reporter = startLoading()
		
		let jsonParser = OperationParseGeoJson(json, reporter: reporter)
		jsonParser.completionBlock = {
			guard !jsonParser.isCancelled else {
				return
			}
			reporter(0.8, "Done", true)	// Close the loading panel
			DispatchQueue.main.async {
				guard jsonParser.world != nil else {
					self.cancelLoad()
					return
				}
				
				switch dataset {
					case .Countries: self.workCountries = jsonParser.world
					case .Regions: self.workRegions = jsonParser.world
				}
				
				if self.workCountries != nil && self.workRegions != nil {
					let fixupJob = OperationFixupHierarchy(countryCollection: self.workCountries!,
																								 regionCollection: self.workRegions!,
																								 reporter: reporter)
					fixupJob.completionBlock = {
						
					}
					
					self.loadQueue.addOperation(fixupJob)
				}
			}
		}
		
		loadJob = jsonParser
		loadQueue.addOperation(jsonParser)
	}

	func finishLoad(loadedWorld: GeoFeatureCollection, dataSet: GeoLoadingViewController.Dataset) {
		workWorld = loadedWorld
		regionOutline.world = loadedWorld
		regionOutline.isHidden = false
		regionOutline.reloadData()
	}
	
	func cancelLoad() {
		if let loading = presentedViewControllers?.last as? GeoLoadingViewController {
			dismiss(loading)
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
			reporter(0.9, "Saving...", false)
			self.finishSave(tempUrl: geometryBaker.tempUrl, saveUrl: url)
			reporter(1.0, "Done", true)	// Close the baking panel
		}
		
		saveJob = geometryBaker
		saveQueue.addOperation(geometryBaker)
	}
	
	func finishSave(tempUrl fromUrl: URL, saveUrl toUrl: URL) {
		do {
			if FileManager.default.fileExists(atPath: toUrl.path) {
				do {
					try FileManager.default.removeItem(at: toUrl)
				} catch (let e) {
					print(e)
				}
			}
			try FileManager.default.moveItem(at: fromUrl, to: toUrl)
		} catch (let e) {
			print(e)
		}
	}
	
	func cancelSave() {
		if let baking = presentedViewControllers?.last as? GeoBakingViewController {
			dismiss(baking)
		}
		if let saveJob = saveJob {
			saveJob.cancel()
		}
	}
}
