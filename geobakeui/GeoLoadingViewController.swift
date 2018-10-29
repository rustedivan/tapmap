//
//  GeoLoadingView.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-13.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import AppKit
import SwiftyJSON

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

extension ViewController : GeoLoadingViewDelegate {
	func startLoading() -> ProgressReport {
		performSegue(withIdentifier: "ShowLoadingProgress", sender: self)
		let loading = presentedViewControllers?.last as! GeoLoadingViewController
		loading.delegate = self
		return loading.progressReporter
	}
	
	func asyncLoadJson(countriesFrom countryUrl: URL, regionsFrom regionUrl: URL) {
		// Load the country/region files
		let countryData: Data
		let regionData: Data
		do {
			countryData = try Data(contentsOf: countryUrl)
			regionData = try Data(contentsOf: regionUrl)
		} catch let e {
			presentError(e)
			return
		}
		
		// Load country/region content json
		let countryJson: JSON
		let regionJson: JSON
		do {
			countryJson = try JSON(data: countryData, options: .allowFragments)
			regionJson = try JSON(data: regionData, options: .allowFragments)
		} catch let error {
			presentError(error)
			return
		}
		
		let reporter = startLoading()
		
		// Parse json into GeoFeaturesCollections
		let jsonParser = OperationParseGeoJson(countries: countryJson, regions: regionJson, reporter: reporter)
		jsonParser.completionBlock = {
			guard !jsonParser.isCancelled else { return	}
			guard jsonParser.countries != nil && jsonParser.regions != nil else {
				DispatchQueue.main.async {
					self.cancelLoad()
				}
				return
			}
			
			reporter(0.9, "Building hierarchy...", false)
			
			let fixupJob = OperationFixupHierarchy(countryCollection: jsonParser.countries!,
																						 regionCollection: jsonParser.regions!,
																						 reporter: reporter)
			fixupJob.completionBlock = {
				reporter(1.0, "Done", true)
				DispatchQueue.main.async {
					self.finishLoad(loadedCountries: fixupJob.countries, loadedRegions: fixupJob.regions)
				}
			}
			self.loadQueue.addOperation(fixupJob)
		}
		
		loadJob = jsonParser
		loadQueue.addOperation(jsonParser)
	}
	
	func finishLoad(loadedCountries: GeoFeatureCollection, loadedRegions: GeoFeatureCollection) {
		workCountries = loadedCountries
		workRegions = loadedRegions
		
		regionOutline.countries = loadedCountries
		regionOutline.regions = loadedRegions
		regionOutline.isHidden = false
		regionOutline.reloadData()
	}
	
	func cancelLoad() {
		if let loading = presentedViewControllers?.last as? GeoLoadingViewController {
			dismiss(loading)
		}
		
		loadJob?.cancel()
	}
}
