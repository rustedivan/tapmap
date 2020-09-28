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
	static let oceanColor = FixableId()
	static let continentColor = FixableId()
	static let unvisitedCountryColor = FixableId()
	static let unvisitedCountryBorderColor = FixableId()
	static let visitedCountryColor = FixableId()
	static let visitedCountryBorderColor = FixableId()
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var fixaStream = FixaStream(fixableSetups: [
		(FixableId(),											 				.divider(display: FixableDisplay("Continents"))),
		(AppFixables.continentBorderInner, 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.continentBorderOuter, 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border outside"))),
		(AppFixables.oceanColor,						 			.color(value: UIColor.blue.cgColor, display: FixableDisplay("Ocean"))),
		(AppFixables.continentColor,				 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Continent"))),
		(FixableId(), 										 				.divider(display: FixableDisplay("Countries"))),
		(AppFixables.countryBorderInner, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderOuter, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.unvisitedCountryColor, 			.color(value: UIColor.red.cgColor, display: FixableDisplay("Unvisited"))),
		(AppFixables.unvisitedCountryBorderColor,	.color(value: UIColor.yellow.cgColor, display: FixableDisplay("Unvisited border"))),
		(AppFixables.visitedCountryColor,					.color(value: UIColor.cyan.cgColor, display: FixableDisplay("Visited"))),
		(AppFixables.visitedCountryBorderColor, 	.color(value: UIColor.magenta.cgColor, display: FixableDisplay("Visited border")))
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

