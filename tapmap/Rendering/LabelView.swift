//
//  LabelView.swift
//  tapmap
//
//  Created by Ivan Milles on 2019-12-21.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import UIKit

class LabelView: UIView {
	@IBOutlet var oneLabel: UILabel!
	
	func updateLabels(_ labels: [(name: String, screenPos: CGPoint)]) {
		oneLabel.text = labels.first?.name
		oneLabel.frame.origin = labels.first?.screenPos ?? .zero
	}
}
