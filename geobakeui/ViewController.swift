//
//  ViewController.swift
//  geobakeui
//
//  Created by Ivan Milles on 2017-04-08.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Cocoa
import SwiftyJSON

class ViewController: NSViewController {

	override func viewDidLoad() {
		super.viewDidLoad()

		for argument in CommandLine.arguments {
			if argument.hasSuffix(".json") {
				let autoloadJson = Bundle.main.bundleURL
					.deletingLastPathComponent()
					.appendingPathComponent(argument)
				_ = loadFeatureJson(url: autoloadJson)
			}
		}
	}

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}


}

