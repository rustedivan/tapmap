//
//  download.swift
//  geobaketool
//
//  Created by Ivan Milles on 2019-01-16.
//  Copyright © 2019 Wildbrain. All rights reserved.
//

import Foundation
import Dispatch

enum GeoBakeDownloadError : Error {
	case timedOut
	case unpackFailed
}

class URLDownloadReporter : NSObject, URLSessionDownloadDelegate {
	let semaphore: DispatchSemaphore
	var tempFilePath: String?
	
	init(doneSemaphore: DispatchSemaphore) {
		semaphore = doneSemaphore
	}
	
	func urlSession(_ session: URLSession,
										 downloadTask: URLSessionDownloadTask,
										 didWriteData bytesWritten: Int64,
										 totalBytesWritten: Int64,
										 totalBytesExpectedToWrite: Int64) {
		print("\(totalBytesWritten)/\(totalBytesExpectedToWrite)")
	}
	
	func urlSession(_ session: URLSession,
										downloadTask: URLSessionDownloadTask,
										didFinishDownloadingTo location: URL) {
		print("Downloaded source archive...")
		let source = location.path
		let destination = FileManager.default.currentDirectoryPath.appending("/temp-source-data.tmp")
		
		do {
			try FileManager.default.moveItem(atPath: source, toPath: destination)
			tempFilePath = destination
		} catch {
			print(error.localizedDescription)
		}
		
		semaphore.signal()
	}
	
	func urlSession(_ session: URLSession,
										task: URLSessionTask,
										didCompleteWithError error: Error?) {
		if let e = error {
			print("Could not connect: \(e.localizedDescription)")
			semaphore.signal()
		}
	}
}

func unpackFile(archivePath: String) throws {
	let task = Process()
	task.launchPath = "/usr/bin/unzip"
	task.arguments = ["temp-source-data.tmp", "-d", "temp"]
	task.launch()
	task.waitUntilExit()
	
	if task.terminationStatus != 0 {
		throw GeoBakeDownloadError.unpackFailed
	}
}

func downloadFiles(params: ArraySlice<String>) throws {
	let semaphore = DispatchSemaphore(value: 0)
	let reporter = URLDownloadReporter(doneSemaphore: semaphore)
	let session = URLSession(configuration: URLSessionConfiguration.ephemeral,
													 		delegate: reporter,
															delegateQueue: nil)
	let tempUrl = URL(string: "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_0_countries.zip")!
	
	let downloadTask = session.downloadTask(with: tempUrl)
	downloadTask.resume()
	
	let result = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(60))
	switch result {
	case DispatchTimeoutResult.timedOut:
		throw GeoBakeDownloadError.timedOut
	default:
		if let tempFilePath = reporter.tempFilePath {
			try unpackFile(archivePath: tempFilePath)
		}
	}
}

