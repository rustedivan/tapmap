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
	case timedOut(host: String)
	case downloadFailed(key: String)
	case unpackFailed
}

func downloadFiles(params: ArraySlice<String>) throws {
	let semaphore = DispatchSemaphore(value: 0)
	let reporter = URLDownloadReporter(doneSemaphore: semaphore)
	let session = URLSession(configuration: URLSessionConfiguration.ephemeral,
													 delegate: reporter,
													 delegateQueue: nil)
	
	let geometryFilesPath = try prepareGeometryDirectory()
	
	let archiveUrls = [PipelineConfig.shared.sourceCountryUrl,
										 PipelineConfig.shared.sourceRegionUrl,
										 PipelineConfig.shared.sourceCitiesUrl]
	let _ = try archiveUrls.map({ (url: URL) -> () in
		let downloadTask = session.downloadTask(with: url)
		downloadTask.resume()
		let result = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(600))
		guard result == DispatchTimeoutResult.success else {
			throw GeoBakeDownloadError.timedOut(host: url.host ?? "No host")
		}
		guard let archiveTempPath = reporter.tempFilePath else {
			throw GeoBakeDownloadError.downloadFailed(key: "source.countries")
		}
	
		let geometryTempPath = try unpackFile(archiveUrl: archiveTempPath)
		try pickGeometryFiles(from: geometryTempPath, to: geometryFilesPath)
	})
}

class URLDownloadReporter : NSObject, URLSessionDownloadDelegate {
	let semaphore: DispatchSemaphore
	var tempFilePath: URL?
	var downloadUpdateCounter: Int = 0
	
	init(doneSemaphore: DispatchSemaphore) {
		semaphore = doneSemaphore
	}
	
	func urlSession(_ session: URLSession,
										 downloadTask: URLSessionDownloadTask,
										 didWriteData bytesWritten: Int64,
										 totalBytesWritten: Int64,
										 totalBytesExpectedToWrite: Int64) {
		let filename = downloadTask.originalRequest?.url?.lastPathComponent ?? "unknown file"
		reportLoad(Double(totalBytesWritten)/Double(totalBytesExpectedToWrite), "Downloading \(filename)...", false)
	}
	
	func urlSession(_ session: URLSession,
										downloadTask: URLSessionDownloadTask,
										didFinishDownloadingTo location: URL) {
		reportLoad(1.0, "Downloaded \(location.lastPathComponent)", true)
		tempFilePath = location
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

func unpackFile(archiveUrl: URL) throws -> URL {
	let tempArea = archiveUrl.lastPathComponent + "-temp"
	let unzipTask = Process()
	unzipTask.launchPath = "/usr/bin/unzip"
	unzipTask.currentDirectoryPath = archiveUrl.deletingLastPathComponent().path
	unzipTask.arguments = ["-o", archiveUrl.lastPathComponent, "-d", tempArea]
	unzipTask.standardOutput = Pipe()
	unzipTask.launch()
	unzipTask.waitUntilExit()
	
	if unzipTask.terminationStatus != 0 {
		throw GeoBakeDownloadError.unpackFailed
	}
	
	return unzipTask.currentDirectoryURL!.appendingPathComponent(tempArea)
}

func prepareGeometryDirectory() throws -> URL {
	let path = FileManager.default.currentDirectoryPath + "/source-geometry"

	if FileManager.default.fileExists(atPath: path) {
		do { try FileManager.default.removeItem(atPath: path)	}
		catch { }
	}
	
	try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
	return URL(fileURLWithPath: path)
}

func pickGeometryFiles(from src: URL, to dst: URL) throws {
	let allFiles = try FileManager.default.contentsOfDirectory(at: src, includingPropertiesForKeys: nil, options: [])
	let usefulFiles = allFiles.filter { $0.pathExtension == "shp" || $0.pathExtension == "dbf" }
	
	_ = try usefulFiles.map {
		try FileManager.default.moveItem(at: $0,
																		 to: dst.appendingPathComponent($0.lastPathComponent))
	}
}
	


