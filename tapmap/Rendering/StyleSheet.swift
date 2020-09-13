//
//  StyleSheet.swift
//  tapmap
//
//  Created by Ivan Milles on 2020-09-13.
//  Copyright © 2020 Wildbrain. All rights reserved.
//

import Foundation

class Stylesheet {
	static let shared = Stylesheet()
	
	var continentBorderWidthInner: Float = 0.2
	var continentBorderWidthOuter: Float = 1.0
	var countryBorderWidthInner: Float = 0.3
	var countryBorderWidthOuter: Float = 0.1
	var provinceBorderWidthInner: Float = 0.3
	var provinceBorderWidthOuter: Float = 0.1
}
