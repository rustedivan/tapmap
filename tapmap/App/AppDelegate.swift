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
		(AppFixables.renderLabels,		 						.bool(display: FixableDisplay("Show labels"))),
		(AppFixables.borderZoomBias,		 					.float(min: 1.0, max: 5.0, display: FixableDisplay("Border zoom bias"))),
		(AppFixables.poiZoomBias,		 							.float(min: 1.0, max: 5.0, display: FixableDisplay("Marker zoom bias"))),
		(FixableId("continent-header"),	 				.divider(display: FixableDisplay("Continents"))),
		(AppFixables.continentBorderInner, 				.float(min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.continentBorderOuter, 				.float(min: 0.0, max: 2.0, display: FixableDisplay("Border outside"))),
		(AppFixables.oceanColor,						 			.color(display: FixableDisplay("Ocean"))),
		(AppFixables.continentSaturation,		 			.float(min: 0.0, max: 1.0, display: FixableDisplay("Continent saturation"))),
		(AppFixables.continentBrightness,		 			.float(min: 0.0, max: 1.0, display: FixableDisplay("Continent brightness"))),
		(FixableId("country-header"),		 				.divider(display: FixableDisplay("Countries"))),
		(AppFixables.countrySaturation,		 				.float(min: 0.0, max: 1.0, display: FixableDisplay("Country saturation"))),
		(AppFixables.countryBrightness,		 				.float(min: 0.0, max: 1.0, display: FixableDisplay("Country brightness"))),
		(AppFixables.countryBorderInner, 	 				.float(min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderOuter, 	 				.float(min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderColor,					.color(display: FixableDisplay("Border color"))),
		(FixableId("province-header"),	 				.divider(display: FixableDisplay("Provinces"))),
		(AppFixables.provinceSaturation,	 				.float(min: 0.0, max: 1.0, display: FixableDisplay("Province saturation"))),
		(AppFixables.provinceBrightness,	 				.float(min: 0.0, max: 1.0, display: FixableDisplay("Province brightness"))),
		(AppFixables.provinceBorderInner, 	 			.float(min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.provinceBorderOuter, 	 			.float(min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.provinceBorderColor, 				.color(display: FixableDisplay("Border color"))),
		(FixableId("tint-header"),							.divider(display: FixableDisplay("Tints"))),
		(AppFixables.tintAfrica,		 							.color(display: FixableDisplay("Hue: Africa"))),
		(AppFixables.tintAntarctica, 							.color(display: FixableDisplay("Hue: Antarctica"))),
		(AppFixables.tintAsia,			 							.color(display: FixableDisplay("Hue: Asia"))),
		(AppFixables.tintEurope,		 							.color(display: FixableDisplay("Hue: Europe"))),
		(AppFixables.tintNorthAmerica,						.color(display: FixableDisplay("Hue: North America"))),
		(AppFixables.tintOceania,									.color(display: FixableDisplay("Hue: Oceania"))),
		(AppFixables.tintSouthAmerica,						.color(display: FixableDisplay("Hue: South America")))
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

