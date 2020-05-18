/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK
import UIKit

class RootViewController: UITabBarController {
    var controlsViewController = ControlViewController()
    var parameterViewController = ParametersViewController()
    var logsViewController = LogsViewController()
    var keysViewController = KeysViewController()

    lazy var tabs: [UIViewController] = [controlsViewController, keysViewController,
                                         parameterViewController, logsViewController]

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
