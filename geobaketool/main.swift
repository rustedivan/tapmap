//
//  main.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-15.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation

let commands = CommandLine.arguments.dropFirst()

switch commands.first {
case "download":
	try downloadFiles(params: commands.dropFirst())
default: print("Usage")
}
