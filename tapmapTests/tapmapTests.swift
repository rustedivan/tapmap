//
//  tapmapTests.swift
//  tapmapTests
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import XCTest
@testable import tapmap

class tapmapTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        XCTestCase.defaultPerformanceMetrics()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testLoadingPerformance() {
        self.measure {
        }
    }
    
}
