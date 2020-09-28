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

class Stylesheet {
	static let shared = Stylesheet()
	
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
	var unvisitedCountryColor = FixableColor(AppFixables.unvisitedCountryColor, initial: UIColor.red.cgColor)
	var unvisitedCountryBorderColor = FixableColor(AppFixables.unvisitedCountryBorderColor, initial: UIColor.yellow.cgColor)
	var visitedCountryColor = FixableColor(AppFixables.visitedCountryColor, initial: UIColor.cyan.cgColor)
	var visitedCountryBorderColor = FixableColor(AppFixables.visitedCountryBorderColor, initial: UIColor.magenta.cgColor)
}
