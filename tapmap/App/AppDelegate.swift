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
	static let continentBorderInner = FixableId()
	static let continentBorderOuter = FixableId()
	static let countryBorderInner = FixableId()
	static let countryBorderOuter = FixableId()
}

//FixableSetup("Continent inside", config: .float(value: 0.1, min: 0.0, max: 2.0))
//FixableSetup("Continent outside", config: .float(value: 0.1, min: 0.0, max: 2.0))
//FixableSetup("Country inside", config: .float(value: 0.1, min: 0.0, max: 2.0))
//FixableSetup("Country outside", config: .float(value: 0.1, min: 0.0, max: 2.0))


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var fixaStream = FixaStream(fixableSetups: [
		FixableId() :											 .divider(display: FixableDisplay("Continents")),
		AppFixables.continentBorderInner : .float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside")),
		AppFixables.continentBorderOuter : .float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border outside")),
		FixableId() : 										 .divider(display: FixableDisplay("Countries")),
		AppFixables.countryBorderInner : 	 .float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside")),
		AppFixables.countryBorderOuter : 	 .float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))
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

