//
//  StyleSheet.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-09-13.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation
import UIKit.UIColor
import fixa
import simd

struct AppFixables {
	static let renderLabels = FixableId("visible-labels")
	static let continentBorderInner = FixableId("continent-border-inner")
	static let continentBorderOuter = FixableId("continent-border-outer")
	static let countryBorderInner = FixableId("country-border-inner")
	static let countryBorderOuter = FixableId("country-border-outer")
	static let provinceBorderInner = FixableId("province-border-inner")
	static let provinceBorderOuter = FixableId("province-border-outer")
	static let borderZoomBias = FixableId("border-zoom-bias")
	static let oceanColor = FixableId("ocean-color")
	static let countryBorderColor = FixableId("country-border-color")
	static let provinceBorderColor = FixableId("province-border-color")
	static let continentSaturation = FixableId("continent-saturation")
	static let continentBrightness = FixableId("continent-brightness")
	static let countrySaturation = FixableId("country-saturation")
	static let countryBrightness = FixableId("country-brightness")
	static let provinceSaturation = FixableId("province-saturation")
	static let provinceBrightness = FixableId("province-brightness")
	static let tintAfrica = FixableId("tint-africa")
	static let tintAntarctica = FixableId("tint-antarctica")
	static let tintAsia = FixableId("tint-asia")
	static let tintEurope = FixableId("tint-europe")
	static let tintNorthAmerica = FixableId("tint-northamerica")
	static let tintOceania = FixableId("tint-oceania")
	static let tintSouthAmerica = FixableId("tint-southamerica")
}

class Stylesheet {
	static let shared = Stylesheet()
	
	// Settings
	var renderLabels = FixableBool(AppFixables.renderLabels, initial: true)
	
	// Border widths
	var continentBorderWidthInner = FixableFloat(AppFixables.continentBorderInner, initial: 0.1)
	var continentBorderWidthOuter = FixableFloat(AppFixables.continentBorderOuter, initial: 0.1)
	var countryBorderWidthInner = FixableFloat(AppFixables.countryBorderInner, initial: 0.1)
	var countryBorderWidthOuter = FixableFloat(AppFixables.countryBorderOuter, initial: 0.1)
	var provinceBorderWidthInner = FixableFloat(AppFixables.provinceBorderInner, initial: 0.1)
	var provinceBorderWidthOuter = FixableFloat(AppFixables.provinceBorderOuter, initial: 0.1)
	var borderZoomBias = FixableFloat(AppFixables.borderZoomBias, initial: 1.0)
	
	// Map colors
	var oceanColor = FixableColor(AppFixables.oceanColor, initial: UIColor(hue: 0.55, saturation: 0.07, brightness: 0.90, alpha: 1.0).cgColor)
	var countryBorderColor = FixableColor(AppFixables.countryBorderColor, initial: UIColor.yellow.cgColor)
	var provinceBorderColor = FixableColor(AppFixables.provinceBorderColor, initial: UIColor.yellow.cgColor)
	
	// Tint controls
	var continentBrightness = FixableFloat(AppFixables.continentBrightness, initial: 0.1)
	var continentSaturation = FixableFloat(AppFixables.continentSaturation, initial: 0.1)
	var countryBrightness = FixableFloat(AppFixables.countryBrightness, initial: 0.1)
	var countrySaturation = FixableFloat(AppFixables.countrySaturation, initial: 0.1)
	var provinceBrightness = FixableFloat(AppFixables.provinceBrightness, initial: 0.1)
	var provinceSaturation = FixableFloat(AppFixables.provinceSaturation, initial: 0.1)
	
	// Continent tints
	var tintAfrica = FixableColor(AppFixables.tintAfrica, initial: UIColor.green.cgColor)
	var tintAntarctica = FixableColor(AppFixables.tintAntarctica, initial: UIColor.green.cgColor)
	var tintAsia = FixableColor(AppFixables.tintAsia, initial: UIColor.green.cgColor)
	var tintEuropa = FixableColor(AppFixables.tintEurope, initial: UIColor.green.cgColor)
	var tintNorthAmerica = FixableColor(AppFixables.tintNorthAmerica, initial: UIColor.green.cgColor)
	var tintEurope = FixableColor(AppFixables.tintOceania, initial: UIColor.green.cgColor)
	var tintSouthAmerica = FixableColor(AppFixables.tintSouthAmerica, initial: UIColor.green.cgColor)

	// Calculated rendering colors from hue x brightness
	var continentColors: [String : simd_float4] = [:]
	var countryColors: [String : simd_float4] = [:]
	
	init() {
		NotificationCenter.default.addObserver(forName: FixaStream.DidUpdateValues, object: nil, queue: nil) { _ in
			self.recalculateTints()
		}
		recalculateTints()
	}
	
	func continentColor(for regionHash: Int, in mapping: GeoContinentMap) -> simd_float4 {
		let continentName = mapping[regionHash]!.name
		return continentColors[continentName] ?? simd_float4([1.0, 0.0, 1.0, 1.0])
	}
	
	func countryColor(for regionHash: Int, in mapping: GeoContinentMap) -> simd_float4 {
		let continentName = mapping[regionHash]!.name
		return countryColors[continentName] ?? simd_float4([1.0, 0.0, 1.0, 1.0])
	}
	
	func recalculateTints() {
		let tints = [
			"Africa" : tintAfrica.value,
			"Antarctica" : tintAntarctica.value,
			"Asia" : tintAsia.value,
			"Europe" : tintEuropa.value,
			"North America" : tintNorthAmerica.value,
			"Oceania" : tintEurope.value,
			"South America" : tintSouthAmerica.value,
		]
		
		for tint in tints {
			continentColors[tint.key] = mixColor(tint.value, continentSaturation.value, continentBrightness.value)
			countryColors[tint.key] = mixColor(tint.value, countrySaturation.value, countryBrightness.value)
		}
	}
	
	func mixColor(_ tint: CGColor, _ saturation: Float, _ brightness: Float) -> simd_float4 {
		var h: CGFloat = 300.0
		let s = CGFloat(saturation)
		let v = CGFloat(brightness)
		UIColor(cgColor: tint).getHue(&h, saturation: nil, brightness: nil, alpha: nil)
		let out = UIColor(hue: h, saturation: s, brightness: v, alpha: 1.0)
		return out.tuple().vector
	}
}

extension FixableColor {
	public var float4: simd_float4 {
		let c = UIColor(cgColor: value).tuple()
		return c.vector
	}
}
