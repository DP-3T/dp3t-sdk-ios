/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@available(iOS 13.5, *)
class HandlerOperation: Operation {
    weak var handler: DP3TBackgroundHandler?

    init(handler: DP3TBackgroundHandler) {
        self.handler = handler
    }

    override func main() {
        handler?.performBackgroundTasks(completionHandler: { success in
            if !success {
                self.cancel()
            }
        })
    }
}
