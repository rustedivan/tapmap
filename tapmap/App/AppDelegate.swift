//
//  AppDelegate.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import UIKit

import fixa

struct AppFixables {
	static let continentBorderInner = FixableSetup("Continent inside", config: .float(value: 0.1, min: 0.0, max: 2.0))
	static let continentBorderOuter = FixableSetup("Continent outside", config: .float(value: 0.1, min: 0.0, max: 2.0))
	static let countryBorderInner = FixableSetup("Country inside", config: .float(value: 0.1, min: 0.0, max: 2.0))
	static let countryBorderOuter = FixableSetup("Country outside", config: .float(value: 0.1, min: 0.0, max: 2.0))
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var fixaStream = FixaStream(fixableSetups: [
		FixableSetup("Borders", config: .divider()),
		AppFixables.continentBorderInner,
		AppFixables.continentBorderOuter,
		AppFixables.countryBorderInner,
		AppFixables.countryBorderOuter
	])
	
	var window: UIWindow?
	var uiState = UIState()
	var userState = UserState()
	static var sharedUIState: UIState { get { return (UIApplication.shared.delegate as! AppDelegate).uiState } }
	static var sharedUserState: UserState { get { return (UIApplication.shared.delegate as! AppDelegate).userState } }
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		fixaStream.startListening()
		return true
	}
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		NSUbiquitousKeyValueStore.default.synchronize()
	}
}

