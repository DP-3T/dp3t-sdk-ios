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

class SyncOperation: Operation {
    override func main() {
        let semaphore = DispatchSemaphore(value: 0)
        DP3TTracing.sync(runningInBackground: true) { result in
            switch result {
            case .failure:
                self.cancel()
            default:
                break
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    override func cancel() {
        DP3TTracing.cancelSync()
    }
}
