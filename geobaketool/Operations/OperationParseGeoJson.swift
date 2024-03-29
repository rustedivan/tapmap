//
//  OperationParseGeoJson.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-16.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import Foundation
import SwiftyJSON

class OperationParseGeoJson : Operation {
	let input : JSON
	let report : ProgressReport
	let level : ToolGeoFeature.Level
	var output : ToolGeoFeatureMap?

	init(json _json: JSON, as _level: ToolGeoFeature.Level, reporter: @escaping ProgressReport) {
		input = _json
		level = _level
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		report(0.0, "Parsing \(level)", false)
		output = parseFeatures(json: input, dataSet: level)
		report(1.0, "Parsed \(level)", true)
	}
	
	fileprivate func parseFeatures(json: JSON,
																 dataSet: ToolGeoFeature.Level) -> ToolGeoFeatureMap? {
		guard json["type"] == "FeatureCollection" else {
			print("Warning: Root node is not multi-feature")
			return ToolGeoFeatureMap()	// This is OK.
		}
		guard let featureArray = json["features"].array else {
			print("Error: Did not find the \"features\" array")
			return nil
		}
		
		let numFeatures = featureArray.count
		var parseCount = 0
		let parsedFeatures = featureArray.compactMap { (featureJson) -> (RegionHash, ToolGeoFeature)? in
			guard let f = parseFeature(featureJson, into: level) else {
				return nil
			}
			report(Double(parseCount) / Double(numFeatures), f.name, false)
			parseCount += 1
			return (f.geographyId.hashed, f)
		}
		
		return ToolGeoFeatureMap(parsedFeatures) { (lhs, rhs) -> ToolGeoFeature in
			print("Key collision between \(lhs.geographyId.key) and \(rhs.geographyId.key)")
			return lhs
		}
	}
	
	fileprivate func parseFeature(_ json: JSON, into level: ToolGeoFeature.Level) -> ToolGeoFeature? {
		let properties = json["properties"]
		guard let featureName = properties["NAME"].string ?? properties["name"].string else {
			print("No name in feature")
			return nil
		}
		guard let featureType = json["geometry"]["type"].string else {
			print("No feature type in geometry for \"\(featureName)\"")
			return nil
		}
		
		let loadedPolygons: [Polygon]

		switch featureType {
			case "MultiPolygon":
				let polygonsJson = json["geometry"]["coordinates"]
				loadedPolygons = polygonsJson.arrayValue.compactMap { parsePolygon($0) }
			case "Polygon":
				let polygonJson = json["geometry"]["coordinates"]
				if let polygon = parsePolygon(polygonJson) {
					loadedPolygons = [polygon]
				} else {
					print("Polygon in \"\(featureName)\" has no coordinate list.")
					loadedPolygons = []
				}
			case "Point":
				let pointJson = json["geometry"]["coordinates"]
				if let point = parsePoint(pointJson) {
					loadedPolygons = [point]
				} else {
					print("Point in \"\(featureName)\" has no coordinate.")
					loadedPolygons = []
				}
			default:
				print("Malformed feature in \(featureName)")
				return nil
		}
		
		// Flatten string/value properties
		let stringProps = properties.dictionaryValue
					.filter { $0.value.type == .string }
					.mapValues { $0.stringValue } as ToolGeoFeature.GeoStringProperties
		let valueProps = properties.dictionaryValue
					.filter { $0.value.type == .number }
					.mapValues { $0.doubleValue } as ToolGeoFeature.GeoValueProperties
		
		return ToolGeoFeature(level: level,
													polygons: loadedPolygons,
													tessellations: [],
													places: nil,
													children: nil,
													stringProperties: stringProps,
													valueProperties: valueProps)
	}
	
	fileprivate func parsePolygon(_ polygonJson: JSON) -> Polygon? {
		guard let ringsJson = polygonJson.array, !ringsJson.isEmpty else {
			print("Polygon has no ring array")
			return nil
		}
		
		let parsedRings = ringsJson.map { parseRing($0.arrayValue) }
		
		return Polygon(rings: parsedRings)
	}
	
	fileprivate func parseRing(_ coords: [JSON]) -> VertexRing {
		var outVertices: [Vertex] = []
		for c in coords {
			guard c.type == .array else {
      	print("Coordinate has unexpected internal type: \(c.type)")
        continue
      }
			
			let v = Vertex(c[0].doubleValue,
										 c[1].doubleValue)
			outVertices.append(v)
		}
		return VertexRing(vertices: outVertices)
	}

	fileprivate func parsePoint(_ pointJson: JSON) -> Polygon? {
		guard pointJson.type == .array else {
			print("Coordinate has unexpected internal type: \(pointJson.type)")
			return nil
		}
		
		let midpoint = Vertex(pointJson[0].doubleValue,
													pointJson[1].doubleValue)
		
		let exteriorRing = makeStar(around: midpoint, radius: 0.1, points: 5)
		return Polygon(rings: [exteriorRing])
	}

	fileprivate func makeStar(around p: Vertex, radius: Float, points: Int) -> VertexRing {
		let vertices = 0..<points * 2
		let angles = vertices.map { p -> Double in
			let a0 = Double.pi / 2.0
			let n = Double(points)
			return Double(a0 + Double(p) * 2.0 * Double.pi / n)
		}

		let circle = angles.map { Vertex(cos($0), sin($0)) }
		let star = circle.enumerated().map { (offset: Int, element: Vertex) -> Vertex in
			let radius = (offset % 2 == 0) ? 1.0 : 0.6
			return Vertex(element.x * radius, element.y * radius)
		}
		let positionedStar = star.map { Vertex($0.x + p.x, $0.y + p.y) }
		return VertexRing(vertices: positionedStar)
	}
}
