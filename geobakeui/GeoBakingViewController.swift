//
//  GeoBakingViewController.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-17.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa

protocol GeoBakingViewDelegate {
	func finishSave(saveUrl toUrl: URL)
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
				
				if done {
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
		if tableColumn?.identifier == "Region" { return warning.0 }
		if tableColumn?.identifier == "Warning" { return warning.1 }
		return nil
	}

	
	@IBAction func cancelSave(sender: NSButton) {
		delegate?.cancelSave()
	}
}
