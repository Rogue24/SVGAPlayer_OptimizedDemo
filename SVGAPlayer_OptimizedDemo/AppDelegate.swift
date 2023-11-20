//
//  AppDelegate.swift
//  SVGAPlayer_OptimizedDemo
//
//  Created by aa on 2023/8/23.
//

import UIKit
import SVProgressHUD

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    @objc var window: UIWindow? {
        set {}
        get {
            if #available(iOS 13.0, *) {
                guard let scene = UIApplication.shared.connectedScenes.first,
                      let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
                      let window = windowSceneDelegate.window
                else {
                    return nil
                }
                return window
            } else {
                return UIApplication.shared.delegate?.window ?? nil
            }
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        SVProgressHUD.setMaxSupportedWindowLevel(.alert)
        SVProgressHUD.setMinimumDismissTimeInterval(1.3)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

