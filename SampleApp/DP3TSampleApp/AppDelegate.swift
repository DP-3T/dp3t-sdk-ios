/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import DP3TSDK
import DP3TSDK_LOGGING_STORAGE
import os
import UIKit
var loggingStorage: DP3TLoggingStorage?

var baseUrl: URL = URL(string: "https://demo.dpppt.org/")!

extension DP3TLoggingStorage: LoggingDelegate {}

func initializeSDK() {
    if loggingStorage == nil {
        loggingStorage = try? .init()
        DP3TTracing.loggingDelegate = loggingStorage
    }
    try! DP3TTracing.initialize(with: .init(appId: "org.dpppt.demo", bucketBaseUrl: baseUrl, reportBaseUrl: baseUrl, mode: .test))
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
