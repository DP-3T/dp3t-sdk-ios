/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@available(iOS 13.5, *)
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
}
