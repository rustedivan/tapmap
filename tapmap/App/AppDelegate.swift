//
//  AppDelegate.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import UIKit

import fixa

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var fixaStream = FixaStream(fixableSetups: [
		(FixableId("general"),	 								.divider(display: FixableDisplay("General"))),
		(AppFixables.renderLabels,		 						.bool(value: true, display: FixableDisplay("Show labels"))),
		(AppFixables.borderZoomBias,		 					.float(value: 1.0, min: 1.0, max: 5.0, display: FixableDisplay("Border zoom bias"))),
		(FixableId("continent-header"),	 				.divider(display: FixableDisplay("Continents"))),
		(AppFixables.continentBorderInner, 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.continentBorderOuter, 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border outside"))),
		(AppFixables.oceanColor,						 			.color(value: UIColor.blue.cgColor, display: FixableDisplay("Ocean"))),
		(AppFixables.continentSaturation,		 			.float(value: 0.03, min: 0.0, max: 1.0, display: FixableDisplay("Continent saturation"))),
		(AppFixables.continentBrightness,		 			.float(value: 0.97, min: 0.0, max: 1.0, display: FixableDisplay("Continent brightness"))),
		(FixableId("country-header"),		 				.divider(display: FixableDisplay("Countries"))),
		(AppFixables.countrySaturation,		 				.float(value: 0.03, min: 0.0, max: 1.0, display: FixableDisplay("Country saturation"))),
		(AppFixables.countryBrightness,		 				.float(value: 0.9, min: 0.0, max: 1.0, display: FixableDisplay("Country brightness"))),
		(AppFixables.countryBorderInner, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderOuter, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderColor,					.color(value: UIColor.yellow.cgColor, display: FixableDisplay("Border color"))),
		(FixableId("province-header"),	 				.divider(display: FixableDisplay("Provinces"))),
		(AppFixables.provinceBorderInner, 	 			.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.provinceBorderOuter, 	 			.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.provinceBorderColor, 				.color(value: UIColor.magenta.cgColor, display: FixableDisplay("Border color"))),
		(FixableId("tint-header"),							.divider(display: FixableDisplay("Tints"))),
		(AppFixables.tintAfrica,		 							.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Africa"))),
		(AppFixables.tintAntarctica, 							.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Antarctica"))),
		(AppFixables.tintAsia,			 							.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Asia"))),
		(AppFixables.tintEurope,		 							.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Europe"))),
		(AppFixables.tintNorthAmerica,						.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: North America"))),
		(AppFixables.tintOceania,									.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Oceania"))),
		(AppFixables.tintSouthAmerica,						.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: South America")))
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

