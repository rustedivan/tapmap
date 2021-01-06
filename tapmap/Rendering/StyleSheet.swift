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
	var continentColor = FixableColor(AppFixables.continentColor, initial: UIColor(hue: 0.00, saturation: 0.00, brightness: 0.97, alpha: 1.0).cgColor)
	var countryColor = FixableColor(AppFixables.countryColor, initial: UIColor(hue: 0.00, saturation: 0.03, brightness: 0.95, alpha: 1.0).cgColor)
	var provinceColor = FixableColor(AppFixables.provinceColor, initial: UIColor(hue: 0.90, saturation: 0.70, brightness: 0.17, alpha: 1.0).cgColor)
	var countryBorderColor = FixableColor(AppFixables.countryBorderColor, initial: UIColor.yellow.cgColor)
	var provinceBorderColor = FixableColor(AppFixables.provinceBorderColor, initial: UIColor.yellow.cgColor)
	
	var continentBrightness = Float(0.2)
	var continentHueAfrica = FixableColor(AppFixables.continentHueAfrica, initial: UIColor.green.cgColor)
	var continentHueAntarctica = FixableColor(AppFixables.continentHueAntarctica, initial: UIColor.green.cgColor)
	var continentHueAsia = FixableColor(AppFixables.continentHueAsia, initial: UIColor.green.cgColor)
	var continentHueEurope = FixableColor(AppFixables.continentHueEurope, initial: UIColor.green.cgColor)
	var continentHueNorthAmerica = FixableColor(AppFixables.continentHueNorthAmerica, initial: UIColor.green.cgColor)
	var continentHueOceania = FixableColor(AppFixables.continentHueOceania, initial: UIColor.green.cgColor)
	var continentHueSouthAmerica = FixableColor(AppFixables.continentHueSouthAmerica, initial: UIColor.green.cgColor)

	// Calculated rendering colors from hue x brightness
	var continentColors: [String : simd_float4] = [:]
	
	init() {
		NotificationCenter.default.addObserver(forName: FixaStream.DidUpdateValues, object: nil, queue: nil) { _ in
			self.recalculateContinentColors()
		}
		recalculateContinentColors()
	}
	
	func recalculateContinentColors() {
		continentColors["Africa"] = mixColor(authored: UIColor(cgColor: continentHueAfrica.value), withBrightness: continentBrightness)
		continentColors["Antarctica"] = mixColor(authored: UIColor(cgColor: continentHueAntarctica.value), withBrightness: continentBrightness)
		continentColors["Asia"] = mixColor(authored: UIColor(cgColor: continentHueAsia.value), withBrightness: continentBrightness)
		continentColors["Europe"] = mixColor(authored: UIColor(cgColor: continentHueEurope.value), withBrightness: continentBrightness)
		continentColors["North America"] = mixColor(authored: UIColor(cgColor: continentHueNorthAmerica.value), withBrightness: continentBrightness)
		continentColors["Oceania"] = mixColor(authored: UIColor(cgColor: continentHueOceania.value), withBrightness: continentBrightness)
		continentColors["South America"] = mixColor(authored: UIColor(cgColor: continentHueSouthAmerica.value), withBrightness: continentBrightness)
	}
	
	func mixColor(authored: UIColor, withBrightness b: Float) -> simd_float4 {
		var h: CGFloat = 300.0
		var s: CGFloat = 1.0
		let v: CGFloat = CGFloat(b)
		authored.getHue(&h, saturation: &s, brightness: nil, alpha: nil)
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
