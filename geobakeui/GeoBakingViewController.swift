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
				try FileManager.default.removeItem(at: toUrl)
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
		
		saveJob?.cancel()
	}
}

