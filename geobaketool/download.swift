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
	case queryFailed(message: String)
	case invalidConfig(message: String)
	case unpackFailed
}

func downloadFiles(params: ArraySlice<String>) throws {
	let semaphore = DispatchSemaphore(value: 0)
	let reporter = URLDownloadReporter(doneSemaphore: semaphore)
	let configuration = URLSessionConfiguration.ephemeral
	configuration.timeoutIntervalForRequest = 600
	let session = URLSession(configuration: configuration,
													 delegate: reporter,
													 delegateQueue: nil)
	
	let geometryFilesPath = try prepareGeometryDirectory()
	
	// Download and unpack NaturalEarth data
	let archiveUrls = [PipelineConfig.shared.configUrl("source.countries"),
										 PipelineConfig.shared.configUrl("source.regions")]
	
	let _ = try archiveUrls.map({ (url: URL?) -> () in
		guard let url = url else { return }
		let downloadTask = session.downloadTask(with: url)
		downloadTask.resume()
		let result = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(600))
		guard result == DispatchTimeoutResult.success else {
			throw GeoBakeDownloadError.timedOut(host: url.host ?? "No host")
		}
		guard let archiveTempPath = reporter.tempFilePath else {
			throw GeoBakeDownloadError.downloadFailed(key: url.lastPathComponent)
		}

		let geometryTempPath = try unpackFile(archiveUrl: archiveTempPath)
		try pickGeometryFiles(from: geometryTempPath, to: geometryFilesPath)
	})

	// Download and move OpenStreetMap data
	let osmQueries = [(PipelineConfig.shared.configUrl("source.osmCitiesUrl"), "osm-cities.json"),
										(PipelineConfig.shared.configUrl("source.osmTownsUrl"), "osm-towns.json")]
	
	let _ = try osmQueries.map({ (url: URL?, dst: String) -> () in
		guard let url = url else { return }
		let downloadTask = session.downloadTask(with: url)
		downloadTask.resume()
		
		reportLoad(0.0, "Waiting for Overpass server to build result for \"\(dst)\"...", false)
		
		let result = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(600))
		guard result == DispatchTimeoutResult.success else {
			throw GeoBakeDownloadError.timedOut(host: url.host ?? "No host")
		}
		guard let queryTempPath = reporter.tempFilePath else {
			throw GeoBakeDownloadError.queryFailed(message: dst)
		}
		
		try pickJsonFiles(from: queryTempPath, named: dst, to: geometryFilesPath)
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

	if !FileManager.default.fileExists(atPath: path) {
		try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
	}
	
	return URL(fileURLWithPath: path)
}

func pickGeometryFiles(from src: URL, to dst: URL) throws {
	let allFiles = try FileManager.default.contentsOfDirectory(at: src, includingPropertiesForKeys: nil, options: [])
	let usefulFiles = allFiles.filter { $0.pathExtension == "shp" || $0.pathExtension == "dbf" }
	
	_ = try usefulFiles.map {
		let target = dst.appendingPathComponent($0.lastPathComponent)
		if FileManager.default.fileExists(atPath: target.absoluteString) {
			do { try FileManager.default.removeItem(atPath: target.absoluteString)	}
			catch { }
		}
		try FileManager.default.moveItem(at: $0,
																		 to: target)
	}
}

func pickJsonFiles(from src: URL, named filename: String, to dst: URL) throws {
	let target = dst.appendingPathComponent(filename)
	
	if FileManager.default.fileExists(atPath: target.absoluteString) {
		do { try FileManager.default.removeItem(atPath: target.absoluteString)	}
		catch { }
	}
	
	try FileManager.default.moveItem(at: src,
																	 to: target)
}
	


