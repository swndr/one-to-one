//
//  AppDelegate.swift
//  OneToOne
//
//  Created by Sam Wander on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        Parse.setApplicationId("myeITsplOiQ4R1ATdPg9fSsF9gNMKBwT8v00OwER", clientKey: "xumfIymIDYPpdxBtoQBY0a3JSGdieXGrUiCWdJeM")
        
                if #available(iOS 8.0, *) {
                    let types: UIUserNotificationType = [.Alert, .Badge, .Sound]
                    let settings = UIUserNotificationSettings(forTypes: types, categories: nil)
                    application.registerUserNotificationSettings(settings)
                    application.registerForRemoteNotifications()
                } else {
                    let types: UIRemoteNotificationType = [.Alert, .Badge, .Sound]
                    application.registerForRemoteNotificationTypes(types)
                }
        
        func handleUserStatus() {
            
            self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            var containerVC = UIViewController()
            var initialVC = UIViewController()
            
            containerVC = storyboard.instantiateViewControllerWithIdentifier("MainViewController")
            
            if self.window != nil {
                print("Found window")
                self.window!.rootViewController = containerVC
            }
            
            switch getCurrentUser() {
            case .None:
                // Go to login
                initialVC = storyboard.instantiateViewControllerWithIdentifier("LoginViewController")
            case .Anonymous:
                // Go to login
                initialVC = storyboard.instantiateViewControllerWithIdentifier("LoginViewController")
            case .Unpaired:
                // Go to pairing screen
                initialVC = storyboard.instantiateViewControllerWithIdentifier("PairingViewController")
            case .Paired:
                // Go to camera
                initialVC = storyboard.instantiateViewControllerWithIdentifier("CameraViewController")
            }
            
            containerVC.addChildViewController(initialVC)
            initialVC.view.frame = containerVC.view.bounds
            containerVC.view.addSubview(initialVC.view)
            initialVC.didMoveToParentViewController(initialVC)
        }
        
        handleUserStatus()
        
        return true
    }
    
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        installation.saveInBackground()
        
        PFPush.subscribeToChannelInBackground("") { (succeeded: Bool, error: NSError?) in
            if succeeded {
                print("OneToOne successfully subscribed to push notifications on the broadcast channel.\n");
            } else {
                print("OneToOne failed to subscribe to push notifications on the broadcast channel with error = %@.\n", error)
            }
        }
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        if error.code == 3010 {
            print("Push notifications are not supported in the iOS Simulator.\n")
        } else {
            print("application:didFailToRegisterForRemoteNotificationsWithError: %@\n", error)
        }
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
//        PFPush.handlePush(userInfo)
        if application.applicationState == UIApplicationState.Inactive {
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
        }
        print(userInfo)
        if userInfo["event"] as! String == "photo" {
            // If photo notif, post notification to center
            NSNotificationCenter.defaultCenter().postNotificationName("newPhoto", object: nil, userInfo: userInfo as [NSObject : AnyObject])
        } else if userInfo["event"] as! String == "paired" {
            // If pairing notif, post notification to center
            NSNotificationCenter.defaultCenter().postNotificationName("justPaired", object: nil, userInfo: userInfo as [NSObject : AnyObject])
        }
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Clear the badge
        let currentInstallation = PFInstallation.currentInstallation()
        if currentInstallation.badge != 0 {
            currentInstallation.badge = 0
            currentInstallation.saveEventually()
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

