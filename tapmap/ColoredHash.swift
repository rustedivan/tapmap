import UIKit.UIColor

extension Hashable {
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
	
	var hashColor: UIColor {
		let hue = bucketHash(hashValue, intoBuckets: 36)
		return UIColor(hue: hue,	saturation: 0.8, brightness: 0.8,	alpha: 1.0)
	}
	
	func hashColor<T:Hashable>(withChild child: T) -> UIColor {
		let hue = bucketHash(hashValue, intoBuckets: 36, withSubhash: child.hashValue)
		let saturation = bucketHash(child.hashValue, intoBuckets: 10)
		let clampedSaturation = min(max(saturation, 0.2), 0.6)
		return UIColor(hue: hue, saturation: clampedSaturation, brightness: 0.8,	alpha: 1.0)
	}
}
