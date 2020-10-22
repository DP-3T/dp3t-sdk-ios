/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

protocol TracerDelegate: AnyObject {
    func stateDidChange()
}

public typealias TracingEnableResult = Result<Void, DP3TTracingError>

protocol Tracer {
    var delegate: TracerDelegate? { get set }

    var state: TrackingState { get }

    var isAuthorized: Bool { get }

    func setEnabled(_ enabled: Bool, completionHandler: ((TracingEnableResult) -> Void)?)
    
    func addInitialisationCallback(callback: @escaping  ()-> Void )
}
