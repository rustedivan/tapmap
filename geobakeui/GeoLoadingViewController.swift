//
//  GeoLoadingView.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-13.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import AppKit

protocol GeoLoadingViewDelegate {
	func finishLoad(loadedCountries: GeoFeatureCollection, loadedRegions: GeoFeatureCollection)
	func cancelLoad()
}

class GeoLoadingViewController: NSViewController {
	@IBOutlet var progressMeter: NSProgressIndicator!
	@IBOutlet var chunkLabel: NSTextField!
	var delegate: GeoLoadingViewDelegate?
	
	enum Dataset {
		case Countries
		case Regions
	}
	
	var progressReporter: ProgressReport {
		return { (p: Double, chunkName: String, done: Bool) in
			// Progress updates on UI thread
			DispatchQueue.main.async {
				self.chunkLabel.stringValue = "Loading \(chunkName)..."
				self.progressMeter.doubleValue = p
				
				if done {
					self.dismiss(self)
				}
			}
		}
	}
	
	@IBAction func cancelLoad(sender: NSButton) {
		delegate?.cancelLoad()
	}
}
