//
//  AppDelegate.swift
//  tapmap
//
//  Created by Ivan Milles on 2017-04-01.
//  Copyright © 2017 Wildbrain. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	var uiState = UIState()
	var userState = UserState()
	static var sharedUIState: UIState { get { return (UIApplication.shared.delegate as! AppDelegate).uiState } }
	static var sharedUserState: UserState { get { return (UIApplication.shared.delegate as! AppDelegate).userState } }
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
		object: NSUbiquitousKeyValueStore.default,
		queue: nil,
		using: takeCloudProfile)
		
		NSUbiquitousKeyValueStore.default.synchronize()
		return true
	}
	
	func takeCloudProfile(notification: Notification) {
		guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? NSArray else { return }
		if changedKeys.contains(UserState.visitedPlacesKey) {
			userState.mergeCloudVisits()
		}
	}
}

