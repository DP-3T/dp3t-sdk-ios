/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

protocol TracerDelegate: AnyObject {
    func stateDidChange()
}

protocol Tracer {
    var delegate: TracerDelegate? { get set }

    var state: TrackingState { get }

    func setEnabled(_ enabled: Bool, completionHandler: ((Error?) -> Void)?)
}
