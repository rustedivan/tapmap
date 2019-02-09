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
	let json : JSON
	let report : ProgressReport
	let level : GeoFeature.Level
	var features : GeoFeatureCollection?

	init(json _json: JSON, as _level: GeoFeature.Level, reporter: @escaping ProgressReport) {
		json = _json
		level = _level
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }
		
		report(0.0, "Parsing \(level)", false)
		features = parseFeatures(json: json, dataSet: level)
		report(1.0, "Parsed \(level)", true)
	}
	
	fileprivate func parseFeatures(json: JSON,
																 dataSet: GeoFeature.Level) -> GeoFeatureCollection? {
		guard json["type"] == "FeatureCollection" else {
			print("Root node is not multi-feature")
			return nil
		}
		guard let featureArray = json["features"].array else {
			print("Did not find the \"features\" array")
			return nil
		}
		
		let numFeatures = featureArray.count
		var loadedFeatures : Set<GeoFeature> = []
		
		for featureJson in featureArray {
			if let loadedFeature = parseFeature(featureJson, into: level) {
				loadedFeatures.insert(loadedFeature)
				report(Double(loadedFeatures.count) / Double(numFeatures), loadedFeature.name, false)
			}
		}
		
		return GeoFeatureCollection(features: loadedFeatures)
	}
	
	fileprivate func parseFeature(_ json: JSON, into level: GeoFeature.Level) -> GeoFeature? {
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
		case .Region: guard PipelineConfig.shared.configArray("bake.regions")?.contains(featureName) ?? true else { return nil }
		case .City: break
		}
		
		let loadedPolygons: [GeoPolygon]

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
					.mapValues { $0.stringValue }
		let valueProps = properties.dictionaryValue
					.filter { $0.value.type == .number }
					.mapValues { $0.doubleValue }
		
		return GeoFeature(level: level, polygons: loadedPolygons, stringProperties: stringProps, valueProperties: valueProps)
	}
	
	fileprivate func parsePolygon(_ polygonJson: JSON) -> GeoPolygon? {
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
		
		return GeoPolygon(exteriorRing: exteriorRing, interiorRings: interiorRings)
	}
	
	fileprivate func parseRing(_ coords: [JSON]) -> GeoPolygonRing {
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
		return GeoPolygonRing(vertices: outVertices)
	}

	fileprivate func parsePoint(_ pointJson: JSON) -> GeoPolygon? {
		guard pointJson.type == .array else {
			print("Coordinate has unexpected internal type: \(pointJson.type)")
			return nil
		}
		
		let midpoint = Vertex(pointJson[0].doubleValue,
													pointJson[1].doubleValue)
		
		let exteriorRing = makeStar(around: midpoint, radius: 0.1, points: 5)
		return GeoPolygon(exteriorRing: exteriorRing, interiorRings: [])
	}

	fileprivate func makeStar(around p: Vertex, radius: Float, points: Int) -> GeoPolygonRing {
		let vertices = 0..<points * 2
		let angles = vertices.map { (Double.pi / 2.0) + Double($0) * (2.0 * Double.pi / Double(points)) }
		let circle = angles.map { Vertex(cos($0), sin($0)) }
		let star = circle.enumerated().map { (offset: Int, element: Vertex) -> Vertex in
			let radius = (offset % 2 == 0) ? 1.0 : 0.6
			return Vertex(element.x * radius, element.y * radius)
		}
		let positionedStar = star.map { Vertex($0.x + p.x, $0.y + p.y) }
		return GeoPolygonRing(vertices: positionedStar)
	}
}
