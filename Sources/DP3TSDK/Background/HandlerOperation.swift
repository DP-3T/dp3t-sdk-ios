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

class HandlerOperation: Operation {
    weak var handler: DP3TBackgroundHandler?

    init(handler: DP3TBackgroundHandler) {
        self.handler = handler
    }

    override func main() {
        let semaphore = DispatchSemaphore(value: 0)
        handler?.performBackgroundTasks(completionHandler: { success in
            if !success {
                self.cancel()
            }
            semaphore.signal()
        })
        semaphore.wait()
    }
}
