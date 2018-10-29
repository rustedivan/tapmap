//
//  GeoBakingViewController.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa

protocol GeoBakingViewDelegate {
	func cancelSave()
}

class GeoBakingViewController: NSViewController, NSTableViewDataSource {
	@IBOutlet var progressMeter: NSProgressIndicator!
	@IBOutlet var chunkLabel: NSTextField!
	@IBOutlet var warningList: NSTableView!
	var delegate: GeoBakingViewDelegate?
	var warnings: [(String, String)] = []
	
	var progressReporter: ProgressReport {
		return { (p: Double, chunkName: String, done: Bool) in
			// Progress updates on UI thread
			DispatchQueue.main.async {
				self.chunkLabel.stringValue = "Baking \(chunkName)..."
				self.progressMeter.doubleValue = p
				
				if done && self.warnings.isEmpty {
					self.dismiss(self)
				}
			}
		}
	}
	
	var errorReporter: ErrorReport {
		return { (region: String, reason: String) in
			self.warnings.append((region, reason))
			// Progress updates on UI thread
			DispatchQueue.main.async {
				self.warningList.reloadData()
			}
		}
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return warnings.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let warning = warnings[row]
		if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Region") { return warning.0 }
		if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Warning") { return warning.1 }
		return nil
	}

	
	@IBAction func cancelSave(sender: NSButton) {
		delegate?.cancelSave()
	}
}

extension ViewController : GeoBakingViewDelegate {
	func startBaking() -> (ProgressReport, ErrorReport) {
		performSegue(withIdentifier: "ShowBakingProgress", sender: self)
		let baking = presentedViewControllers?.last as! GeoBakingViewController
		baking.delegate = self
		return (baking.progressReporter, baking.errorReporter)
	}
	
	func asyncBakeGeometry(to saveUrl: URL) {
		let (reporter, errorReporter) = startBaking()
		guard let bakeCountries = workCountries, let bakeRegions = workRegions else {
			print("Baking without working set")
			return
		}
		
		let geometryBaker = OperationBakeGeometry(countries: bakeCountries,
																							region: bakeRegions,
																							saveUrl: saveUrl,
																							reporter: reporter,
																							errorReporter: errorReporter)
		geometryBaker.completionBlock = {
			guard !geometryBaker.isCancelled else { return }
			guard geometryBaker.error == nil else {
				print(String(describing: geometryBaker.error))
				return
			}
			
			reporter(1.0, "Done", false)	// Close the baking panel
		}
		
		saveJob = geometryBaker
		saveQueue.addOperation(geometryBaker)
	}
	
	func cancelSave() {
		if let baking = presentedViewControllers?.last as? GeoBakingViewController {
			dismiss(baking)
		}
		
		saveJob?.cancel()
	}
}

