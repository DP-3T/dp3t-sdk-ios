/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

class SyncOperation: Operation {
    override func main() {
        DP3TTracing.sync { result in
            switch result {
            case .failure:
                self.cancel()
            default:
                break
            }
        }
    }
    override func cancel() {
        DP3TTracing.cancelSync()
    }
}
