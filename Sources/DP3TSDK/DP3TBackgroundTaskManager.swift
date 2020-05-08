/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import BackgroundTasks
import Foundation
import UIKit.UIApplication

private class SyncOperation: Operation {
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

private class HandlerOperation: Operation {
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

/// Background task registration should only happen once per run
/// If the SDK gets destroyed and initialized again this would cause a crash
private var didRegisterBackgroundTask: Bool = false

@available(iOS 13.0, *)
class DP3TBackgroundTaskManager {
    static let taskIdentifier: String = "org.dpppt.exposure-notification"

    /// A logger for debugging
    #if CALIBRATION
        public weak var logger: LoggingDelegate?
    #endif

    weak var handler: DP3TBackgroundHandler?

    init(handler: DP3TBackgroundHandler?) {
        self.handler = handler
    }

    /// Register a background task
    func register() {
        guard !didRegisterBackgroundTask else { return }
        didRegisterBackgroundTask = true

        #if CALIBRATION
            logger?.log(type: .backgroundTask, "DP3TBackgroundTaskManager.register")
        #endif

        BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.taskIdentifier, using: .main) { task in
            self.handleBackgroundTask(task)
        }

        scheduleBackgroundTask()
    }

    private func handleBackgroundTask(_ task: BGTask) {
        #if CALIBRATION
            logger?.log(type: .backgroundTask, "DP3TBackgroundTaskManager.handleBackgroundTask")
        #endif

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        if let handler = handler {
            queue.addOperation(HandlerOperation(handler: handler))
        }

        queue.addOperation(SyncOperation())

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        scheduleBackgroundTask()

        let lastOperation = queue.operations.last
        lastOperation?.completionBlock = {
            task.setTaskCompleted(success: !(lastOperation?.isCancelled ?? false))
        }
    }

    private func scheduleBackgroundTask() {
        let taskRequest = BGProcessingTaskRequest(identifier: DP3TBackgroundTaskManager.taskIdentifier)
        taskRequest.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch {
            #if CALIBRATION
                logger?.log(type: .backgroundTask, "Unable to submit task: \(error.localizedDescription)")
            #endif
        }
    }
}
