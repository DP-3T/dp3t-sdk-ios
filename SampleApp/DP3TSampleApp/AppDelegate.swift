/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK_CALIBRATION
import os
import UIKit

func initializeSDK() {
    /// Can be initialized either by:
    /// - using the discovery:
    let appVersion: String
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
        appVersion = "\(version)(\(build))"
    } else {
        appVersion = "N/A"
    }
    #if canImport(ExposureNotification)
    try! DP3TTracing.initialize(with: .discovery("org.dpppt.demo", enviroment: .dev),
                                mode: .exposureNotificationFramework)
    #else
    try! DP3TTracing.initialize(with: .discovery("org.dpppt.demo", enviroment: .dev),
    mode: .customImplementationCalibration(identifierPrefix: Default.shared.identifierPrefix ?? "", appVersion: appVersion))
    #endif
    /// - passing the url:
    // try! DP3TTracing.initialize(with: .manual(.init(appId: "org.dpppt.demo", bucketBaseUrl: URL(string: "https://demo.dpppt.org/")!, reportBaseUrl: URL(string: "https://demo.dpppt.org/")!, jwtPublicKey: nil)),
    //                            mode: .calibration(identifierPrefix: Default.shared.identifierPrefix ?? ""))
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initializeSDK()

        if application.applicationState != .background {
            initWindow()
        }

        switch Default.shared.tracingMode {
        case .none:
            break
        case .active:
            try? DP3TTracing.startTracing()
        }

        return true
    }

    func initWindow() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKey()
        window?.rootViewController = RootViewController()
        window?.makeKeyAndVisible()
    }

    func applicationWillEnterForeground(_: UIApplication) {
        if window == nil {
            initWindow()
        }
    }
}
