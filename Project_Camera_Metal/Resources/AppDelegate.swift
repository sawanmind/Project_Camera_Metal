//
//  AppDelegate.swift
//  Project_Camera_Metal
//
//  Created by iOS Development on 7/2/18.
//  Copyright © 2018 Genisys. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = CameraViewController()
        return true
    }

 


}

