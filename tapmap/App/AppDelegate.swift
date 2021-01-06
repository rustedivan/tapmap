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
	static let countrySaturation = FixableId("country-saturation")
	static let countryBrightness = FixableId("country-brightness")
	static let countryBorderInner = FixableId("country-border-inner")
	static let countryBorderOuter = FixableId("country-border-outer")
	static let provinceBorderInner = FixableId("province-border-inner")
	static let provinceBorderOuter = FixableId("province-border-outer")
	static let borderZoomBias = FixableId("border-zoom-bias")
	static let oceanColor = FixableId("ocean-color")
	static let continentColor = FixableId("continent-color")
	static let countryColor = FixableId("country-color")
	static let provinceColor = FixableId("province-color")
	static let countryBorderColor = FixableId("country-border-color")
	static let provinceBorderColor = FixableId("province-border-color")
	static let continentSaturation = FixableId("continent-saturation")
	static let continentBrightness = FixableId("continent-brightness")
	static let continentHueAfrica = FixableId("continent-hue-africa")
	static let continentHueAntarctica = FixableId("continent-hue-antarctica")
	static let continentHueAsia = FixableId("continent-hue-asia")
	static let continentHueEurope = FixableId("continent-hue-europe")
	static let continentHueNorthAmerica = FixableId("continent-hue-northamerica")
	static let continentHueOceania = FixableId("continent-hue-oceania")
	static let continentHueSouthAmerica = FixableId("continent-hue-southamerica")
}

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
		(AppFixables.continentColor,				 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Fill color"))),
		(AppFixables.continentSaturation,		 			.float(value: 0.03, min: 0.0, max: 1.0, display: FixableDisplay("Continent saturation"))),
		(AppFixables.continentBrightness,		 			.float(value: 0.97, min: 0.0, max: 1.0, display: FixableDisplay("Continent brightness"))),
		(AppFixables.continentHueAfrica,		 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Africa"))),
		(AppFixables.continentHueAntarctica, 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Antarctica"))),
		(AppFixables.continentHueAsia,			 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Asia"))),
		(AppFixables.continentHueEurope,		 			.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Europe"))),
		(AppFixables.continentHueNorthAmerica,		.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: North America"))),
		(AppFixables.continentHueOceania,					.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: Oceania"))),
		(AppFixables.continentHueSouthAmerica,		.color(value: UIColor.green.cgColor, display: FixableDisplay("Hue: South America"))),
		(FixableId("country-header"),		 				.divider(display: FixableDisplay("Countries"))),
		(AppFixables.countrySaturation,		 				.float(value: 0.03, min: 0.0, max: 1.0, display: FixableDisplay("Country saturation"))),
		(AppFixables.countryBrightness,		 				.float(value: 0.9, min: 0.0, max: 1.0, display: FixableDisplay("Country brightness"))),
		(AppFixables.countryBorderInner, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryBorderOuter, 	 				.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.countryColor,					 			.color(value: UIColor.red.cgColor, display: FixableDisplay("Fill color"))),
		(AppFixables.countryBorderColor,					.color(value: UIColor.yellow.cgColor, display: FixableDisplay("Border color"))),
		(FixableId("province-header"),	 				.divider(display: FixableDisplay("Provinces"))),
		(AppFixables.provinceBorderInner, 	 			.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.provinceBorderOuter, 	 			.float(value: 0.1, min: 0.0, max: 2.0, display: FixableDisplay("Border inside"))),
		(AppFixables.provinceColor, 							.color(value: UIColor.magenta.cgColor, display: FixableDisplay("Province color"))),
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

