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
import UIKit

class RootViewController: UITabBarController {

    lazy var tabs: [UIViewController] = {
        if #available(iOS 13.0, *) {
            return [ControlViewController(),
             ParametersViewController(),
             LogsViewController(),
             KeysViewController()]
        } else {
            return [ControlViewController(),
             ParametersViewController(),
             LogsViewController()]
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = tabs.map(UINavigationController.init(rootViewController:))

        DP3TTracing.delegate = self
    }
}

extension RootViewController: DP3TTracingDelegate {
    func DP3TTracingStateChanged(_ state: TracingState) {
        tabs
            .compactMap { $0 as? DP3TTracingDelegate }
            .forEach { $0.DP3TTracingStateChanged(state) }
    }
}
