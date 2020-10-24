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
	var provinceBorderWidthInner: Float = 0.3
	var provinceBorderWidthOuter: Float = 0.1
	
	// Map colors
	var oceanColor = FixableColor(AppFixables.oceanColor, initial: UIColor.blue.cgColor)
	var continentColor = FixableColor(AppFixables.continentColor, initial: UIColor.green.cgColor)
	var countryColor = FixableColor(AppFixables.countryColor, initial: UIColor.red.cgColor)
	var countryBorderColor = FixableColor(AppFixables.countryBorderColor, initial: UIColor.yellow.cgColor)
	var provinceBorderColor = FixableColor(AppFixables.provinceBorderColor, initial: UIColor.yellow.cgColor)
}

extension FixableColor {
	public var float4: simd_float4 {
		let c = UIColor(cgColor: value).tuple()
		return c.vector
	}
}
