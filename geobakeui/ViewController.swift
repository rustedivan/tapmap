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
	static let loadQueue = DispatchQueue(label: "se.rusted.tapmap.loadgeography", attributes: [])
	
	override func viewDidAppear() {
		tryAutobakeWithArgument(arguments: CommandLine.arguments)
	}
	
	func tryAutobakeWithArgument(arguments: [String]) {
		for argument in arguments {
			if argument.hasSuffix(".json") {
				let autoloadJson = Bundle.main.bundleURL
					.deletingLastPathComponent()
					.appendingPathComponent(argument)
				let json = loadJsonFile(url: autoloadJson)
				let reporter = startLoading()
				ViewController.loadQueue.async {
					_ = parseFeatureJson(json, progressReporter: reporter)
					reporter(1.0, "Done", true)
				}
			}
		}
	}
}

extension ViewController {
	func startLoading() -> ProgressReport {
		performSegue(withIdentifier: "ShowLoadingProgress", sender: self)
		let loading = presentedViewControllers?.last as! GeoLoadingViewController
		return loading.progressReporter
	}
}
