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
	static let renderLabels = FixableId("visible-labels")
	static let continentBorderInner = FixableId("continent-border-inner")
	static let continentBorderOuter = FixableId("continent-border-outer")
	static let countryBorderInner = FixableId("country-border-inner")
	static let countryBorderOuter = FixableId("country-border-outer")
	static let oceanColor = FixableId("ocean-color")
	static let continentColor = FixableId("continent-color")
	static let countryColor = FixableId("country-color")
	static let countryBorderColor = FixableId("country-border-color")
	static let provinceBorderColor = FixableId("province-border-color")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var fixaStream = FixaStream(fixableSetups: [
		(AppFixables.renderLabels,		 						.bool(value: true, display: FixableDisplay("Show labels"))),
		(FixableId("continent-header"),	 				.divider(display: FixableDisplay("Continents"))),
		(AppFixables.continentBorderInner, 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.continentBorderOuter, 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border outside"))),
		(AppFixables.oceanColor,						 			.color(value: UIColor.blue.cgColor, display: FixableDisplay("Ocean"))),
		(AppFixables.continentColor,				 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Fill color"))),
		(FixableId("country-header"),		 				.divider(display: FixableDisplay("Countries"))),
		(AppFixables.countryBorderInner, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderOuter, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryColor,					 			.color(value: UIColor.red.cgColor, display: FixableDisplay("Fill color"))),
		(AppFixables.countryBorderColor,					.color(value: UIColor.yellow.cgColor, display: FixableDisplay("Border color"))),
		(FixableId("province-header"),	 				.divider(display: FixableDisplay("Provinces"))),
		(AppFixables.provinceBorderColor, 				.color(value: UIColor.magenta.cgColor, display: FixableDisplay("Border color")))
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

