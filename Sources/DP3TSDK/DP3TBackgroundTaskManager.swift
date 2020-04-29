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
        guard DP3TTracing.isInitialized else { return }

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

/// Background task registration should only happen once per run
/// If the SDK gets destroyed and initialized again this would cause a crash
private var didRegisterBackgroundTask: Bool = false

@available(iOS 13.0, *)
class DP3TBackgroundTaskManager {
    static let taskIdentifier: String = "org.dpppt.synctask"

    static let syncInterval: TimeInterval = 15 * .minute

    /// A logger for debugging
    #if CALIBRATION
        public weak var logger: LoggingDelegate?
    #endif

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didEnterBackgroundNotification,
                                                  object: nil)
    }

    /// Register a background task
    func register() {
        guard !didRegisterBackgroundTask else { return }
        didRegisterBackgroundTask = true
        #if CALIBRATION
            logger?.log(type: .backgroundTask, "DP3TBackgroundTaskManager.register")
        #endif
        BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.taskIdentifier, using: .global()) { task in
            self.handleBackgroundTask(task)
        }
    }

    private func handleBackgroundTask(_ task: BGTask) {
        #if CALIBRATION
            logger?.log(type: .backgroundTask, "DP3TBackgroundTaskManager.handleBackgroundTask")
        #endif

        scheduleBackgroundTask()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        queue.addOperation(SyncOperation())

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        let lastOperation = queue.operations.last
        lastOperation?.completionBlock = {
            task.setTaskCompleted(success: !(lastOperation?.isCancelled ?? false))
        }
    }

    private func scheduleBackgroundTask() {
        let syncTask = BGAppRefreshTaskRequest(identifier: DP3TBackgroundTaskManager.taskIdentifier)
        syncTask.earliestBeginDate = Date(timeIntervalSinceNow: DP3TBackgroundTaskManager.syncInterval)
        #if CALIBRATION
            logger?.log(type: .backgroundTask, "DP3TBackgroundTaskManager.scheduleBackgroundTask earliestBeginDate: \(syncTask.earliestBeginDate!)")
        #endif
        do {
            try BGTaskScheduler.shared.submit(syncTask)
        } catch {
            #if CALIBRATION
                logger?.log(type: .backgroundTask, "Unable to submit task: \(error.localizedDescription)")
            #endif
        }
    }

    @objc
    private func didEnterBackground() {
        scheduleBackgroundTask()
    }
}
