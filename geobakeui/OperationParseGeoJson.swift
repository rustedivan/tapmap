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
	var world : GeoFeatureCollection?
	
	init(_ geoJson: JSON, reporter: @escaping ProgressReport) {
		json = geoJson
		report = reporter
	}
	
	override func main() {
		guard !isCancelled else { print("Cancelled before starting"); return }

        guard json["type"] == "FeatureCollection" else {
            print("Root node is not multi-feature")
            return
        }
    
        guard let featureArray = json["features"].array else {
            print("Did not find country \"features\" array")
            return
        }

        let numFeatures = featureArray.count
        var loadedFeatures : [GeoFeature] = []
		for featureJson in featureArray {
            if let loadedFeature = parseFeature(featureJson) {
                loadedFeatures.append(loadedFeature)
                
                let name = loadedFeature.properties["NAME"] ?? loadedFeature.properties["name"] ?? "Unnamed"
                report(Double(loadedFeatures.count) / Double(numFeatures), name, false)
            }
		}
        
        world = GeoFeatureCollection(features: loadedFeatures)
	}
	
	fileprivate func parseFeature(_ json: JSON) -> GeoFeature? {
		let properties = json["properties"]
		guard let featureName = properties["NAME"].string ?? properties["name"].string else {
			print("No name in feature")
			return nil
		}
		guard let featureType = json["geometry"]["type"].string else {
			print("No feature type in geometry for \"\(featureName)\"")
      return nil
        }
        
        let loadedPolygons: [GeoPolygon]

		switch featureType {
        case "MultiPolygon":
            let polygonsJson = json["geometry"]["coordinates"]
            loadedPolygons = polygonsJson.arrayValue.flatMap { parsePolygon($0) }
        case "Polygon":
            let polygonJson = json["geometry"]["coordinates"]
            if let polygon = parsePolygon(polygonJson) {
                loadedPolygons = [polygon]
            } else {
                print("Polygon in \"\(featureName)\" has no coordinate list.")
                loadedPolygons = []
            }
        default:
            print("Malformed feature in \(featureName)")
            return nil
        }
        
        // Flatten string/value properties
        let stringProperties = properties.dictionaryValue
            .filter { $0.value.type == .string }
            .mapValues { $0.stringValue }
        let valueProperties = properties.dictionaryValue
            .filter { $0.value.type == .number }
            .mapValues { $0.doubleValue }
        
        return GeoFeature(polygons: loadedPolygons, properties: stringProperties, values: valueProperties)
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
            let v = Vertex(v: (c[0].floatValue,
                               c[1].floatValue))
			outVertices.append(v)
		}
        return GeoPolygonRing(vertices: outVertices)
	}
}
