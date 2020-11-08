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
	
	// Map colors
	var oceanColor = FixableColor(AppFixables.oceanColor, initial: UIColor(hue: 0.55, saturation: 0.07, brightness: 0.90, alpha: 1.0).cgColor)
	var continentColor = FixableColor(AppFixables.continentColor, initial: UIColor(hue: 0.00, saturation: 0.00, brightness: 0.97, alpha: 1.0).cgColor)
	var countryColor = FixableColor(AppFixables.countryColor, initial: UIColor(hue: 0.00, saturation: 0.03, brightness: 0.95, alpha: 1.0).cgColor)
	var provinceColor = FixableColor(AppFixables.provinceColor, initial: UIColor(hue: 0.90, saturation: 0.70, brightness: 0.17, alpha: 1.0).cgColor)
	var countryBorderColor = FixableColor(AppFixables.countryBorderColor, initial: UIColor.yellow.cgColor)
	var provinceBorderColor = FixableColor(AppFixables.provinceBorderColor, initial: UIColor.yellow.cgColor)
}

extension FixableColor {
	public var float4: simd_float4 {
		let c = UIColor(cgColor: value).tuple()
		return c.vector
	}
}
