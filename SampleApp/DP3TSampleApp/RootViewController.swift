/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK_CALIBRATION
import UIKit

class RootViewController: UITabBarController {
    var logsViewController = LogsViewController()
    var controlsViewController = ControlViewController()
    var parameterViewController = ParametersViewController()
    var handshakeViewController = HandshakeViewController()

    lazy var tabs: [UIViewController] = [controlsViewController,
                                         logsViewController,
                                         parameterViewController,
                                         handshakeViewController]

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

    func didAddLog(_ entry: LogEntry) {
        tabs
            .compactMap { $0 as? DP3TTracingDelegate }
            .forEach { $0.didAddLog(entry) }
    }

    func didAddHandshake(_ handshake: HandshakeModel) {
        tabs
            .compactMap { $0 as? DP3TTracingDelegate }
            .forEach { $0.didAddHandshake(handshake) }
    }
}
