//
//  AppDelegate.swift
//  Raivo
//
//  Created by Tijme Gommers on 26/01/2019.
//  Copyright © 2019 Tijme Gommers. All rights reserved.
//

import UIKit
import RealmSwift
import CloudKit
import SwiftyBeaver
import SDWebImage
import SDWebImageSVGCoder

let log = SwiftyBeaver.self

//@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    public var window: UIWindow?
    
    public var currentStoryboardName: String? = nil
    
    public var previousStoryboardName: String? = nil
    
    private var encryptionKey: Data?
    
    private var iconsEffect: String? = nil
    
    /// When the application finished launching
    ///
    /// - Parameter application: The application as passed to `UIApplicationDelegate`
    /// - Parameter launchOptions: The launchOptions as passed to `UIApplicationDelegate`
    /// - Returns: `true` if the url contained in the `launchOptions` was intended for Raivo
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize debug logging (if applicable)
        let console = ConsoleDestination()
        log.addDestination(console)
        
        // Initialize SDImage configurations
        SDImageCache.shared.config.maxDiskAge = TimeInterval(60 * 60 * 24 * 365 * 4)
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
        
        // If this is the first run of the app, flush the keychain
        // It could be a reinstall of the app (reinstalls don't flush the keychain)
        // https://stackoverflow.com/questions/4747404/delete-keychain-items-when-an-app-is-uninstalled
        if StateHelper.isFirstRun() {
           StorageHelper.clear()
        }
        
        // Run all migrations except Realm migrations
        MigrationHelper.runGenericMigrations()
        
        updateEncryptionKey(encryptionKey)
        
        // Preload the synchronization information
        SyncerHelper.getSyncer().preloadAccount()
        
        // Show the correct storyboard
        self.setCorrectStoryboard()
        
        return true
    }
    
    public func updateEncryptionKey(_ encryptionKey: Data?) {
        self.encryptionKey = encryptionKey
        RealmHelper.initDefaultRealmConfiguration(encryptionKey: encryptionKey)
    }
    
    public func getEncryptionKey() -> Data? {
        return encryptionKey
    }
    
    public func getIconEffect() -> String {
        if let iconEffect = self.iconsEffect {
            return iconEffect
        }
        
        self.iconsEffect = StorageHelper.getIconsEffect()
        
        if self.iconsEffect == nil {
            self.iconsEffect = MiscellaneousIconsEffectFormOption.OPTION_DEFAULT.value
        }
        
        return self.iconsEffect!
    }
    
    private func beforeStoryboardChange(_ storyboard: String) {
        switch storyboard {
        case StateHelper.Storyboard.MAIN:
            // Enable lockscreen timer
            (MyApplication.shared as! MyApplication).enableInactivityTimer()
            
            // Enable syncer notifications
            SyncerHelper.getSyncer().enable()
            SyncerHelper.getSyncer().resyncModel(Password.UNIQUE_ID)
            UIApplication.shared.registerForRemoteNotifications()
        case StateHelper.Storyboard.SETUP:
            // Disable lockscreen timer
            (MyApplication.shared as! MyApplication).disableInactivityTimer()
            
            // Disable syncer notifications and preload the encryption challenge
            SyncerHelper.getSyncer().preloadChallenge()
            UIApplication.shared.unregisterForRemoteNotifications()
            SyncerHelper.getSyncer().disable()
        default:
            // Disable lockscreen timer
            (MyApplication.shared as! MyApplication).disableInactivityTimer()
            
            // Disable syncer notifications
            UIApplication.shared.unregisterForRemoteNotifications()
            SyncerHelper.getSyncer().disable()
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        SyncerHelper.getSyncer().notify(userInfo)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        previousStoryboardName = nil
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func setCorrectStoryboard() {
        let storyboardName = StateHelper.getCurrentStoryboard()
        let controllerName = StateHelper.getCurrentStoryboardController()
        
        beforeStoryboardChange(storyboardName)
        
        if let current = currentStoryboardName {
            previousStoryboardName = current
        }
        
        currentStoryboardName = storyboardName
        
        log.verbose("Changing Storyboard: " + storyboardName)
        
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: controllerName)
        self.window?.rootViewController = controller
    }
    
    func updateStoryboard() {
        self.setCorrectStoryboard()
        
        UIView.transition(
            with: UIApplication.shared.keyWindow!,
            duration: 0.5,
            options: UIView.AnimationOptions.transitionFlipFromLeft,
            animations: nil,
            completion: nil
        )
    }

}