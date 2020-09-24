//
//  StyleSheet.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-09-13.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

import fixa

class Stylesheet {
	static let shared = Stylesheet()
	
	var continentBorderWidthInner = FixableFloat(AppFixables.continentBorderInner)
	var continentBorderWidthOuter = FixableFloat(AppFixables.continentBorderOuter)
	var countryBorderWidthInner = FixableFloat(AppFixables.countryBorderInner)
	var countryBorderWidthOuter = FixableFloat(AppFixables.countryBorderOuter)
	var provinceBorderWidthInner: Float = 0.3
	var provinceBorderWidthOuter: Float = 0.1
}
