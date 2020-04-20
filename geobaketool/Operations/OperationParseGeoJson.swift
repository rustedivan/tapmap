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
		
		var loadedFeatures : ToolGeoFeatureMap = [:]
		let numFeatures = featureArray.count
		
		for featureJson in featureArray {
			if let loadedFeature = parseFeature(featureJson, into: level) {
				loadedFeatures[loadedFeature.geographyId.hashed] = loadedFeature
				report(Double(loadedFeatures.count) / Double(numFeatures), loadedFeature.name, false)
			}
		}
		
		return loadedFeatures
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
		
		// Filter on pipeline settings before parsing JSON
		switch level {
		case .Continent: break
		case .Country: guard PipelineConfig.shared.configArray("bake.countries")?.contains(featureName) ?? true else { return nil }
		case .Province: guard PipelineConfig.shared.configArray("bake.regions")?.contains(featureName) ?? true else { return nil }
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
		
		guard let exteriorRingJson = ringsJson.first?.array else {
			print("Polygon's exterior ring has no elements.")
			return nil
		}
		let exteriorRing = parseRing(exteriorRingJson)
		
		let interiorRingsJson = ringsJson.dropFirst()
		let interiorRings = interiorRingsJson.map { parseRing($0.arrayValue) }
		
		return Polygon(exteriorRing: exteriorRing, interiorRings: interiorRings)
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
		return Polygon(exteriorRing: exteriorRing, interiorRings: [])
	}

	fileprivate func makeStar(around p: Vertex, radius: Float, points: Int) -> VertexRing {
		let vertices = 0..<points * 2
		let angles = vertices.map { (Double.pi / 2.0) + Double($0) * (2.0 * Double.pi / Double(points)) }
		let circle = angles.map { Vertex(cos($0), sin($0)) }
		let star = circle.enumerated().map { (offset: Int, element: Vertex) -> Vertex in
			let radius = (offset % 2 == 0) ? 1.0 : 0.6
			return Vertex(element.x * radius, element.y * radius)
		}
		let positionedStar = star.map { Vertex($0.x + p.x, $0.y + p.y) }
		return VertexRing(vertices: positionedStar)
	}
}
