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

class GeoBakingViewController: NSViewController {
	@IBOutlet var progressMeter: NSProgressIndicator!
	@IBOutlet var chunkLabel: NSTextField!
	var delegate: GeoBakingViewDelegate?
	
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
	
	@IBAction func cancelSave(sender: NSButton) {
		delegate?.cancelSave()
	}
}
