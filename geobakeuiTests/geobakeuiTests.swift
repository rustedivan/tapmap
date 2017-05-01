//
//  geobakeuiTests.swift
//  geobakeuiTests
//
//  Created by Ivan Milles on 2017-05-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import XCTest

class geobakeuiTests: XCTestCase {
    
    func testExample() {
			let tessJob = OperationTesselateBorders()
			tessJob.tesselate()
    }
}
