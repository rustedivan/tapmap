import UIKit.UIColor

extension Hashable {
	var hashColor: UIColor {
		return hashColor(ofHash: hashValue, childHash: 0)
	}
	
	func hashColor<T:Hashable>(withChild child: T) -> UIColor {
		return hashColor(withChildHash: child.hashValue)
	}
	
	func hashColor(withChildHash childHash: Int) -> UIColor {
		return hashColor(ofHash: hashValue, childHash: childHash)
	}
	
	func hashColor(ofHash hash: Int, childHash: Int) -> UIColor {
		let hue = bucketHash(hash, intoBuckets: 36, withSubhash: childHash)
		let saturation = bucketHash(childHash, intoBuckets: 10)
		let clampedSaturation = min(max(saturation, 0.4), 0.8)
		return UIColor(hue: hue, saturation: clampedSaturation, brightness: 0.8,	alpha: 1.0)
	}
	
	private func bucketHash(_ hashValue: Int,
													intoBuckets buckets: Int,
													withSubhash subhash: Int = 0) -> CGFloat {
		let index = abs(hashValue) % buckets
		let normal = Double(index) / Double(buckets)
		
		let width = 2.0 / Double(buckets)
		let subBuckets = 10
		let subIndex = abs(subhash) % subBuckets
		let subNormal = Double(subIndex - (subBuckets / 2)) / Double(subBuckets)
		let offset = subNormal * width
		return CGFloat(abs(normal + offset))
	}
}
